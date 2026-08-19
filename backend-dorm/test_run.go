package main

import (
	"log"
	"os"
	"backend-dorm/core"
)

func main() {
	f, _ := os.Create("crash.log")
	log.SetOutput(f)
	defer f.Close()
	core.RunServer()
}
