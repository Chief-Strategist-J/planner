package scheduler

import (
	"context"
	"log"
	"sync"
	"time"

	"planner/src/features/tasks/repository"
	"planner/src/features/tasks/types"
	"planner/src/infra/email"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: DAILY TASK SCHEDULER ENGINE
==========================================================
1. Background Ticker Lifecycle:
   - Manages a background goroutine firing at a configured interval (default 24h / 1440m).
   - Responds to stop signals via channel coordination to ensure graceful shutdown without data loss.
2. Sweep Execution Logic:
   - Scans all project YAML repositories to retrieve pending task records.
   - Aggregates tasks by recipient:
     a. If AssignedToEmail is populated, aggregates under that recipient address.
     b. If AssignedToEmail is blank, aggregates under the default fallback address ("team@planner.internal").
   - Dispatches one digest email per distinct recipient containing all relevant pending tasks.
   - Computes and returns structured SchedulerSweepResult metrics.
3. On-Demand Trigger Support:
   - Exposes TriggerSweep(ctx) publicly so administrators or automated triggers can invoke sweeps via API.
*/

type DailySchedulerEngine struct {
	repo            repository.TaskRepositoryPort
	emailAdapter    email.EmailNotificationPort
	interval        time.Duration
	fallbackAddress string
	stopChan        chan struct{}
	wg              sync.WaitGroup
	running         bool
	mu              sync.Mutex
}

func NewDailySchedulerEngine(
	repo repository.TaskRepositoryPort,
	emailAdapter email.EmailNotificationPort,
	intervalMinutes int,
	fallbackAddress string,
) *DailySchedulerEngine {
	if intervalMinutes <= 0 {
		intervalMinutes = 1440
	}
	if fallbackAddress == "" {
		fallbackAddress = "team@planner.internal"
	}
	return &DailySchedulerEngine{
		repo:            repo,
		emailAdapter:    emailAdapter,
		interval:        time.Duration(intervalMinutes) * time.Minute,
		fallbackAddress: fallbackAddress,
		stopChan:        make(chan struct{}),
	}
}

func (s *DailySchedulerEngine) Start() {
	s.mu.Lock()
	if s.running {
		s.mu.Unlock()
		return
	}
	s.running = true
	s.mu.Unlock()

	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		ticker := time.NewTicker(s.interval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
				_, err := s.TriggerSweep(ctx)
				if err != nil {
					log.Printf("[SCHEDULER-ERROR] Daily sweep failed: %v", err)
				}
				cancel()
			case <-s.stopChan:
				return
			}
		}
	}()
}

func (s *DailySchedulerEngine) Stop() {
	s.mu.Lock()
	if !s.running {
		s.mu.Unlock()
		return
	}
	s.running = false
	close(s.stopChan)
	s.mu.Unlock()

	s.wg.Wait()
}

func (s *DailySchedulerEngine) TriggerSweep(ctx context.Context) (*types.SchedulerSweepResult, error) {
	pendingByProject, err := s.repo.ListAllPendingTasks(ctx)
	if err != nil {
		return nil, err
	}

	scannedProjects := len(pendingByProject)
	totalPending := 0
	tasksByRecipient := make(map[string][]types.Task)

	for _, taskList := range pendingByProject {
		for _, task := range taskList {
			totalPending++
			recipient := task.AssignedToEmail
			if recipient == "" {
				recipient = s.fallbackAddress
			}
			tasksByRecipient[recipient] = append(tasksByRecipient[recipient], task)
		}
	}

	emailsDispatched := 0
	for recipient, tasks := range tasksByRecipient {
		if err := s.emailAdapter.SendDailyPendingTasksDigest(ctx, recipient, tasks); err == nil {
			emailsDispatched++
		} else {
			log.Printf("[SCHEDULER-WARNING] Failed to send email to %s: %v", recipient, err)
		}
	}

	result := &types.SchedulerSweepResult{
		ScannedProjects:   scannedProjects,
		PendingTasksFound: totalPending,
		EmailsDispatched:  emailsDispatched,
	}

	log.Printf("[SCHEDULER-SWEEP] Projects scanned: %d | Pending tasks: %d | Emails sent: %d",
		result.ScannedProjects, result.PendingTasksFound, result.EmailsDispatched)

	return result, nil
}
