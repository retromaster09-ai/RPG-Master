// Serves the portable Flutter web build on the user's Windows computer.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"time"
)

const addr = "127.0.0.1:8142"

var versionPattern = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$`)

type buildInfo struct {
	AppName string `json:"app_name"`
	Version string `json:"version"`
}

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
	metadata, err := os.ReadFile(filepath.Join(web, "version.json"))
	if err != nil {
		return errors.New("Extraia todos os arquivos do ZIP e abra o programa junto da pasta web.")
	}
	var build buildInfo
	if json.Unmarshal(metadata, &build) != nil || build.AppName != "rpg_master_set" || !versionPattern.MatchString(build.Version) {
		return errors.New("Não foi possível identificar a versão. Extraia o ZIP completo novamente.")
	}

	prefix := "/pc/" + build.Version + "/"
	url := "http://" + addr + prefix
	listener, err := net.Listen("tcp4", addr)
	if err != nil {
		if version := runningVersion(); version != "" {
			return fmt.Errorf("A versão %s já está aberta. Feche a janela do lançador dessa versão e abra a versão %s novamente.", version, build.Version)
		}
		return fmt.Errorf("Não foi possível abrir %s. Feche o lançador anterior antes de abrir a versão %s.", addr, build.Version)
	}
	defer listener.Close()

	fmt.Printf("RPG Master Set %s\n%s\nMantenha esta janela aberta enquanto estiver usando o app.\n", build.Version, url)
	server := &http.Server{
		Handler:           siteHandler(web, prefix),
		ReadHeaderTimeout: 5 * time.Second,
	}
	openBrowser(url)
	if err := server.Serve(listener); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

func siteHandler(web, prefix string) http.Handler {
	mux := http.NewServeMux()
	mux.Handle(prefix, http.StripPrefix(prefix, http.FileServer(http.Dir(web))))
	mux.HandleFunc("/version.json", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, filepath.Join(web, "version.json"))
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		http.Redirect(w, r, prefix, http.StatusTemporaryRedirect)
	})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		mux.ServeHTTP(w, r)
	})
}

func runningVersion() string {
	client := &http.Client{
		Timeout: 1200 * time.Millisecond,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	response, err := client.Get("http://" + addr + "/version.json")
	if err != nil {
		return ""
	}
	defer response.Body.Close()
	var build buildInfo
	if response.StatusCode != http.StatusOK ||
		json.NewDecoder(io.LimitReader(response.Body, 4096)).Decode(&build) != nil ||
		build.AppName != "rpg_master_set" || !versionPattern.MatchString(build.Version) {
		return ""
	}
	return build.Version
}

func openBrowser(url string) {
	if runtime.GOOS != "windows" {
		return
	}
	browser := exec.Command("rundll32.exe", "url.dll,FileProtocolHandler", url)
	if err := browser.Start(); err != nil {
		fmt.Printf("Abra %s no navegador.\n", url)
	} else {
		go func() { _ = browser.Wait() }()
	}
}
