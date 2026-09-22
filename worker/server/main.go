package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"planner/src/api/rest/v1/handlers"
	"planner/src/api/rest/v1/router"
	projRepo "planner/src/features/projects/repository"
	projSvc "planner/src/features/projects/service"
	taskRepo "planner/src/features/tasks/repository"
	taskSvc "planner/src/features/tasks/service"
	"planner/src/infra/config"
	"planner/src/infra/email"
	"planner/src/infra/scheduler"
	"planner/src/shared/middleware"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: HTTP SERVER & SCHEDULER BOOTSTRAPPER
===================================================================
1. CLI Flag & Configuration Ingestion:
   - Evaluates `--sweep-only` flag to support headless scheduled CI execution without starting the HTTP server.
   - Locates and parses `config/default.yaml` with environment variable overrides.
2. Dependency Graph Construction:
   - Instantiates YamlProjectRepository and YamlTaskRepository rooted in configured projects directory.
   - Instantiates domain ProjectsService and TasksService with injected repository ports.
   - Instantiates SmtpEmailAdapter configured for logger or SMTP dispatch.
   - Instantiates DailySchedulerEngine wired to task repository and email ports.
3. Execution Branches:
   - CLI Sweep Mode: If `--sweep-only` is provided, executes one sweep, writes GitHub step summary (if in CI), and exits.
   - Server Mode: Launches HTTP server with explicit timeout protections and graceful signal termination.
*/

func main() {
	sweepOnly := flag.Bool("sweep-only", false, "Execute single sweep for pending tasks and exit")
	flag.Parse()

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

	taskRepository, err := taskRepo.NewYamlTaskRepository(cfg.Storage.ProjectsDirectory)
	if err != nil {
		log.Fatalf("[FATAL] Failed to initialize YAML task repository: %v", err)
	}

	projectRepository, err := projRepo.NewYamlProjectRepository(cfg.Storage.ProjectsDirectory)
	if err != nil {
		log.Fatalf("[FATAL] Failed to initialize YAML project repository: %v", err)
	}

	taskService := taskSvc.NewTasksService(taskRepository)
	projectService := projSvc.NewProjectsService(projectRepository)

	smtpConf := email.SmtpConfig{
		Host:     cfg.Email.Smtp.Host,
		Port:     cfg.Email.Smtp.Port,
		Username: cfg.Email.Smtp.Username,
		Password: cfg.Email.Smtp.Password,
	}
	emailAdapter := email.NewSmtpEmailAdapter(cfg.Email.Mode, cfg.Email.FromAddress, smtpConf)

	sched := scheduler.NewDailySchedulerEngine(
		taskRepository,
		emailAdapter,
		cfg.Scheduler.IntervalMinutes,
		"team@planner.internal",
	)

	if *sweepOnly {
		log.Println("[INFO] Executing pending task sweep in CLI mode...")
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		res, err := sched.TriggerSweep(ctx)
		if err != nil {
			log.Fatalf("[FATAL] Sweep execution failed: %v", err)
		}
		log.Printf("[SUCCESS] Sweep finished. Projects: %d | Pending Tasks: %d | Emails Dispatched: %d",
			res.ScannedProjects, res.PendingTasksFound, res.EmailsDispatched)
		return
	}

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
	tasksHandler := handlers.NewTasksRestHandler(taskService, sched)
	projectsHandler := handlers.NewProjectsRestHandler(projectService)

	tasksRouter := router.NewTasksRouter(tasksHandler, projectsHandler, idempotencyStore, cfg.Server.ApiVersion)
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
