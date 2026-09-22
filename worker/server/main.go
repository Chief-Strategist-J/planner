package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"planner/src/api/rest/v1/handlers"
	"planner/src/api/rest/v1/router"
	"planner/src/features/tasks/repository"
	"planner/src/features/tasks/service"
	"planner/src/infra/config"
	"planner/src/infra/email"
	"planner/src/infra/scheduler"
	"planner/src/shared/middleware"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: HTTP SERVER & SCHEDULER BOOTSTRAPPER
===================================================================
1. Configuration Ingestion:
   - Locates and parses `config/default.yaml` with environment variable overrides.
2. Dependency Graph Construction:
   - Instantiates YamlTaskRepository rooted in configured projects directory.
   - Instantiates pure domain TasksService with injected repository port.
   - Instantiates SmtpEmailAdapter configured for logger or SMTP dispatch.
   - Instantiates DailySchedulerEngine wired to repository and email ports.
   - Instantiates IdempotencyStore for duplicate mutation suppression.
   - Instantiates TasksRestHandler and TasksRouter.
3. Subsystem Lifecycle & Graceful Termination:
   - Spawns DailySchedulerEngine background ticker if enabled.
   - Launches HTTP server with explicit timeout protections.
   - Traps SIGINT and SIGTERM OS signals to execute coordinated graceful shutdown.
*/

func main() {
	cfgPath := "config/default.yaml"
	if customPath := os.Getenv("CONFIG_PATH"); customPath != "" {
		cfgPath = customPath
	} else if _, err := os.Stat(cfgPath); os.IsNotExist(err) {
		if _, err2 := os.Stat("worker/" + cfgPath); err2 == nil {
			cfgPath = "worker/" + cfgPath
		}
	}

	cfg, err := config.LoadConfig(cfgPath)
	if err != nil {
		log.Fatalf("[FATAL] Failed to load configuration: %v", err)
	}

	repo, err := repository.NewYamlTaskRepository(cfg.Storage.ProjectsDirectory)
	if err != nil {
		log.Fatalf("[FATAL] Failed to initialize YAML repository: %v", err)
	}

	taskService := service.NewTasksService(repo)

	smtpConf := email.SmtpConfig{
		Host:     cfg.Email.Smtp.Host,
		Port:     cfg.Email.Smtp.Port,
		Username: cfg.Email.Smtp.Username,
		Password: cfg.Email.Smtp.Password,
	}
	emailAdapter := email.NewSmtpEmailAdapter(cfg.Email.Mode, cfg.Email.FromAddress, smtpConf)

	sched := scheduler.NewDailySchedulerEngine(
		repo,
		emailAdapter,
		cfg.Scheduler.IntervalMinutes,
		"team@planner.internal",
	)

	if cfg.Scheduler.Enabled {
		sched.Start()
		log.Printf("[INFO] Daily task scheduler started (interval: %d minutes)", cfg.Scheduler.IntervalMinutes)
		if cfg.Scheduler.SweepOnStartup {
			go func() {
				ctx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
				defer cancel()
				_, _ = sched.TriggerSweep(ctx)
			}()
		}
	}

	idempotencyStore := middleware.NewIdempotencyStore()
	restHandler := handlers.NewTasksRestHandler(taskService, sched)
	tasksRouter := router.NewTasksRouter(restHandler, idempotencyStore, cfg.Server.ApiVersion)
	httpHandler := tasksRouter.SetupRoutes()

	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	server := &http.Server{
		Addr:              addr,
		Handler:           httpHandler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	serverErrors := make(chan error, 1)
	go func() {
		log.Printf("[INFO] Planner Server listening on http://0.0.0.0:%d (API Version: %s)", cfg.Server.Port, cfg.Server.ApiVersion)
		serverErrors <- server.ListenAndServe()
	}()

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("[FATAL] HTTP server runtime failure: %v", err)
		}
	case sig := <-shutdown:
		log.Printf("[INFO] Received shutdown signal: %v. Initiating graceful drain...", sig)

		if cfg.Scheduler.Enabled {
			sched.Stop()
			log.Printf("[INFO] Scheduler stopped")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			_ = server.Close()
			log.Fatalf("[FATAL] Forceful server termination: %v", err)
		}
		log.Printf("[INFO] Graceful shutdown completed cleanly")
	}
}
