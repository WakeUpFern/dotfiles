package main

import (
	"os"

	"github.com/WakeUpFern/dotfiles/tools/cli/internal/theme"
)

func main() {
	theme.Run(os.Args[1:])
}
