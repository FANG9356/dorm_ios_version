package utils

import "testing"

func TestIsSafeBackupNameAcceptsLegacyAndServerArchives(t *testing.T) {
	tests := []struct {
		name string
		want bool
	}{
		{name: "backup_2026-09-10_01-02-03.zip", want: true},
		{name: "server_backup_2026-09-10_01-02-03.zip", want: true},
		{name: "server_backup_2026-09-10_01-02-03.ZIP", want: true},
		{name: "server_backup_2026-09-10_01-02-03.json", want: false},
		{name: "other_backup_2026-09-10.zip", want: false},
		{name: "../server_backup_2026-09-10.zip", want: false},
		{name: "/tmp/server_backup_2026-09-10.zip", want: false},
		{name: "", want: false},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := IsSafeBackupName(test.name); got != test.want {
				t.Fatalf("IsSafeBackupName(%q) = %v, want %v", test.name, got, test.want)
			}
		})
	}
}
