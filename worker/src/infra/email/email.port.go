package email

import (
	"context"

	"planner/src/features/tasks/types"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: EMAIL NOTIFICATION PORT
======================================================
1. Hexagonal Decoupling:
   - Defines the contract for dispatching email digests for pending tasks.
   - Shields the core scheduler engine from transport specifics (SMTP, SES, Sendgrid, Console Logger).
2. Contract Definition:
   - SendDailyPendingTasksDigest: Transmits a collection of pending tasks to the designated recipient.
*/

type EmailNotificationPort interface {
	SendDailyPendingTasksDigest(ctx context.Context, recipient string, tasks []types.Task) error
}
