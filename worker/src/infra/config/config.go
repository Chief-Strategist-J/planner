package config

import (
	"fmt"
	"os"
	"strconv"

	"gopkg.in/yaml.v3"
)

/*
TOP-LEVEL ALGORITHM BLUEPRINT: STRONGLY-TYPED CONFIG LOADER
===========================================================
1. Baseline File Ingestion:
   - Reads declarative settings from `config/default.yaml`.
   - Populates typed configuration structs with baseline values.
2. Environment Variable Overrides:
   - Evaluates PORT, API_VERSION, PROJECTS_DIR, SCHEDULER_INTERVAL, EMAIL_MODE, SMTP_* env vars.
   - Applies overrides seamlessly on top of baseline file configurations.
*/

type ServerConfig struct {
	Port       int    `yaml:"port"`
	ApiVersion string `yaml:"apiVersion"`
}

type StorageConfig struct {
	Type              string `yaml:"type"`
	ProjectsDirectory string `yaml:"projectsDirectory"`
	GcpProjectId      string `yaml:"gcpProjectId"`
	FirestoreDatabase string `yaml:"firestoreDatabase"`
}

type SchedulerConfig struct {
	Enabled         bool `yaml:"enabled"`
	IntervalMinutes int  `yaml:"intervalMinutes"`
	SweepOnStartup  bool `yaml:"sweepOnStartup"`
}

type SmtpConfig struct {
	Host     string `yaml:"host"`
	Port     int    `yaml:"port"`
	Username string `yaml:"username"`
	Password string `yaml:"password"`
}

type EmailConfig struct {
	Mode        string     `yaml:"mode"`
	FromAddress string     `yaml:"fromAddress"`
	Smtp        SmtpConfig `yaml:"smtp"`
}

type AppConfig struct {
	Server    ServerConfig    `yaml:"server"`
	Storage   StorageConfig   `yaml:"storage"`
	Scheduler SchedulerConfig `yaml:"scheduler"`
	Email     EmailConfig     `yaml:"email"`
}

func LoadConfig(configPath string) (*AppConfig, error) {
	cfg := &AppConfig{
		Server: ServerConfig{
			Port:       8080,
			ApiVersion: "v1",
		},
		Storage: StorageConfig{
			Type:              "yaml",
			ProjectsDirectory: "./projects",
			GcpProjectId:      "planner-app-66733",
			FirestoreDatabase: "(default)",
		},
		Scheduler: SchedulerConfig{
			Enabled:         true,
			IntervalMinutes: 1440,
			SweepOnStartup:  false,
		},
		Email: EmailConfig{
			Mode:        "logger",
			FromAddress: "noreply@planner.internal",
		},
	}

	if configPath != "" {
		data, err := os.ReadFile(configPath)
		if err == nil {
			_ = yaml.Unmarshal(data, cfg)
		}
	}

	if portStr := os.Getenv("PORT"); portStr != "" {
		if p, err := strconv.Atoi(portStr); err == nil {
			cfg.Server.Port = p
		}
	}

	if storageType := os.Getenv("STORAGE_TYPE"); storageType != "" {
		cfg.Storage.Type = storageType
	}

	if projectsDir := os.Getenv("PROJECTS_DIR"); projectsDir != "" {
		cfg.Storage.ProjectsDirectory = projectsDir
	}

	if gcpProjectId := os.Getenv("GCP_PROJECT_ID"); gcpProjectId != "" {
		cfg.Storage.GcpProjectId = gcpProjectId
	}

	if firestoreDb := os.Getenv("FIRESTORE_DATABASE"); firestoreDb != "" {
		cfg.Storage.FirestoreDatabase = firestoreDb
	}

	if emailMode := os.Getenv("EMAIL_MODE"); emailMode != "" {
		cfg.Email.Mode = emailMode
	}

	if smtpHost := os.Getenv("SMTP_HOST"); smtpHost != "" {
		cfg.Email.Smtp.Host = smtpHost
	}

	if smtpPortStr := os.Getenv("SMTP_PORT"); smtpPortStr != "" {
		if sp, err := strconv.Atoi(smtpPortStr); err == nil {
			cfg.Email.Smtp.Port = sp
		}
	}

	if smtpUser := os.Getenv("SMTP_USERNAME"); smtpUser != "" {
		cfg.Email.Smtp.Username = smtpUser
	}

	if smtpPass := os.Getenv("SMTP_PASSWORD"); smtpPass != "" {
		cfg.Email.Smtp.Password = smtpPass
	}

	if cfg.Server.Port <= 0 {
		return nil, fmt.Errorf("invalid server port: %d", cfg.Server.Port)
	}

	return cfg, nil
}
