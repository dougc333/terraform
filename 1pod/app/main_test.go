package main

import (
	"io/fs"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"testing/fstest"
)

func testUI() fs.FS {
	return fstest.MapFS{
		"index.html": {Data: []byte("<!doctype html><title>One-Pod UI</title>")},
		"assets/app.js": {Data: []byte("console.log('ui')")},
	}
}

func TestRootServesUIWithoutWorkQuery(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	response := httptest.NewRecorder()

	rootHandler(testUI()).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if !strings.Contains(response.Body.String(), "One-Pod UI") {
		t.Fatalf("response body %q does not contain UI", response.Body.String())
	}
}

func TestRootPreservesWorkloadResponse(t *testing.T) {
	tests := []struct {
		name     string
		url      string
		wantWork string
	}{
		{name: "requested work", url: "/?work=17", wantWork: "work=17"},
		{name: "empty work uses fallback", url: "/?work=", wantWork: "work=50000"},
		{name: "work is capped", url: "/?work=9000000", wantWork: "work=5000000"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, test.url, nil)
			response := httptest.NewRecorder()

			rootHandler(testUI()).ServeHTTP(response, request)

			if response.Code != http.StatusOK {
				t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
			}
			if contentType := response.Header().Get("Content-Type"); contentType != "text/plain; charset=utf-8" {
				t.Fatalf("Content-Type = %q", contentType)
			}
			if !strings.Contains(response.Body.String(), test.wantWork) {
				t.Fatalf("response body %q does not contain %q", response.Body.String(), test.wantWork)
			}
		})
	}
}

func TestStaticAssetAndUnknownPath(t *testing.T) {
	handler := rootHandler(testUI())

	assetRequest := httptest.NewRequest(http.MethodGet, "/assets/app.js", nil)
	assetResponse := httptest.NewRecorder()
	handler.ServeHTTP(assetResponse, assetRequest)
	if assetResponse.Code != http.StatusOK {
		t.Fatalf("asset status = %d, want %d", assetResponse.Code, http.StatusOK)
	}

	missingRequest := httptest.NewRequest(http.MethodGet, "/missing", nil)
	missingResponse := httptest.NewRecorder()
	handler.ServeHTTP(missingResponse, missingRequest)
	if missingResponse.Code != http.StatusNotFound {
		t.Fatalf("missing status = %d, want %d", missingResponse.Code, http.StatusNotFound)
	}
}

func TestAPIWorkRoute(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/api/work?work=23", nil)
	response := httptest.NewRecorder()

	newServer(testUI()).Handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if !strings.Contains(response.Body.String(), "work=23") {
		t.Fatalf("response body %q does not contain work value", response.Body.String())
	}
}
