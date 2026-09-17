package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"

	"dorm_os/handlers"
	_ "github.com/mattn/go-sqlite3"
)

func main() {
	masterPath := flag.String("master", "", "master SQLite database path")
	tenantPath := flag.String("tenant", "", "tenant SQLite database path")
	accountID := flag.Int("account", 0, "account ID")
	flag.Parse()
	if *masterPath == "" || *tenantPath == "" || *accountID <= 0 {
		log.Fatal("master, tenant, and a positive account are required")
	}

	master, err := sql.Open("sqlite3", *masterPath)
	if err != nil {
		log.Fatal(err)
	}
	defer master.Close()
	tenant, err := sql.Open("sqlite3", *tenantPath)
	if err != nil {
		log.Fatal(err)
	}
	defer tenant.Close()

	if err := handlers.PublishLineTenantChanges(master, tenant, *accountID); err != nil {
		log.Fatal(err)
	}
	fmt.Println("published")
}
