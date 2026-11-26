// Serves the portable Flutter web build on the user's Windows computer.
package main

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		if runtime.GOOS == "windows" {
			fmt.Print("Pressione Enter para fechar.")
			_, _ = fmt.Scanln()
		}
		os.Exit(1)
	}
}

func run() error {
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	web := filepath.Join(filepath.Dir(executable), "web")
	if _, err := os.Stat(filepath.Join(web, "index.html")); err != nil {
		return errors.New("Extraia todos os arquivos do ZIP e abra o programa junto da pasta web.")
	}

	// A stable loopback origin lets the browser reuse the user's session.
	const addr = "127.0.0.1:8142"
	listener, err := net.Listen("tcp4", addr)
	if err != nil {
		return fmt.Errorf("O endereço local %s está ocupado. Feche a outra janela do RPG Master Set e tente novamente.", addr)
	}
	defer listener.Close()

	url := "http://" + addr + "/"
	fmt.Printf("RPG Master Set está em %s\nMantenha esta janela aberta enquanto estiver usando o app.\n", url)
	if runtime.GOOS == "windows" {
		browser := exec.Command("rundll32.exe", "url.dll,FileProtocolHandler", url)
		if err := browser.Start(); err != nil {
			fmt.Printf("Abra %s no navegador.\n", url)
		} else {
			go func() { _ = browser.Wait() }()
		}
	}

	server := &http.Server{
		Handler:           http.FileServer(http.Dir(web)),
		ReadHeaderTimeout: 5 * time.Second,
	}
	if err := server.Serve(listener); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
