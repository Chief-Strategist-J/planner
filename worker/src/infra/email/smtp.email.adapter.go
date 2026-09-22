package email

import (
	"context"
	"fmt"
	"log"
	"net/smtp"
	"strings"

	"planner/src/features/tasks/types"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: EMAIL NOTIFICATION ADAPTER
=========================================================
1. Dual Operation Modes:
   - "logger": Emits structured log output for development, testing, and local verification without live SMTP credentials.
   - "smtp": Constructs RFC 5322 MIME messages and dispatches them via authenticated TLS/plain net/smtp connection.
2. Digest Message Construction:
   - Formats a clean, readable ASCII summary listing pending tasks with identifiers, titles, and due dates.
3. Zero-Inline-Comment Doctrine:
   - Operates cleanly without inline or block comments in the execution body.
*/

type SmtpConfig struct {
	Host     string
	Port     int
	Username string
	Password string
}

type SmtpEmailAdapter struct {
	mode        string
	fromAddress string
	smtpConfig  SmtpConfig
}

func NewSmtpEmailAdapter(mode string, fromAddress string, smtpConfig SmtpConfig) *SmtpEmailAdapter {
	if mode == "" {
		mode = "logger"
	}
	if fromAddress == "" {
		fromAddress = "noreply@planner.internal"
	}
	return &SmtpEmailAdapter{
		mode:        mode,
		fromAddress: fromAddress,
		smtpConfig:  smtpConfig,
	}
}

func (a *SmtpEmailAdapter) buildMessageBody(recipient string, tasks []types.Task) string {
	var builder strings.Builder
	builder.WriteString(fmt.Sprintf("To: %s\r\n", recipient))
	builder.WriteString(fmt.Sprintf("From: %s\r\n", a.fromAddress))
	builder.WriteString("Subject: [Planner] Daily Pending Tasks Digest\r\n")
	builder.WriteString("MIME-Version: 1.0\r\n")
	builder.WriteString("Content-Type: text/plain; charset=UTF-8\r\n\r\n")

	builder.WriteString(fmt.Sprintf("Hello,\n\nYou have %d pending task(s) awaiting completion:\n\n", len(tasks)))
	for i, t := range tasks {
		due := t.DueDate
		if due == "" {
			due = "No due date specified"
		}
		builder.WriteString(fmt.Sprintf("%d. [%s] %s (Project: %s | Due: %s)\n", i+1, t.TaskId, t.Title, t.ProjectId, due))
		if t.Description != "" {
			builder.WriteString(fmt.Sprintf("   Details: %s\n", t.Description))
		}
	}
	builder.WriteString("\nPlease review and update their statuses in the Planner API.\n")
	return builder.String()
}

func (a *SmtpEmailAdapter) SendDailyPendingTasksDigest(ctx context.Context, recipient string, tasks []types.Task) error {
	if len(tasks) == 0 {
		return nil
	}

	body := a.buildMessageBody(recipient, tasks)

	if a.mode == "logger" || a.smtpConfig.Host == "" {
		log.Printf("[EMAIL-DISPATCH-MOCK] Recipient: %s | PendingTasks: %d\n--- MESSAGE ---\n%s\n--- END ---", recipient, len(tasks), body)
		return nil
	}

	auth := smtp.PlainAuth("", a.smtpConfig.Username, a.smtpConfig.Password, a.smtpConfig.Host)
	addr := fmt.Sprintf("%s:%d", a.smtpConfig.Host, a.smtpConfig.Port)

	return smtp.SendMail(addr, auth, a.fromAddress, []string{recipient}, []byte(body))
}
