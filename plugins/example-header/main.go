// Package main implements the reference Higress Proxy-Wasm plugin.
//
// The plugin stamps a configurable request header. It is intentionally small:
// it demonstrates configuration parsing, request-phase interception and the
// artifact shape expected by the OCI packaging pipeline.
package main

import (
	"github.com/higress-group/wasm-go/pkg/log"
	"github.com/higress-group/wasm-go/pkg/types"
	"github.com/higress-group/wasm-go/pkg/wrapper"
	"github.com/tidwall/gjson"
)

// main remains empty. Higress invokes callbacks registered during initialization.
func main() {}

func init() {
	wrapper.SetCtx(
		"example-header",
		wrapper.ParseConfigBy(parseConfig),
		wrapper.ProcessRequestHeadersBy(onHttpRequestHeaders),
	)
}

// Config models the JSON document supplied under spec.config.
type Config struct {
	HeaderName  string `json:"header_name"`
	HeaderValue string `json:"header_value"`
}

// parseConfig applies defaults so the plugin remains safe with an empty config.
func parseConfig(json gjson.Result, config *Config, logger log.Log) error {
	config.HeaderName = json.Get("header_name").String()
	config.HeaderValue = json.Get("header_value").String()

	if config.HeaderName == "" {
		config.HeaderName = "x-higress-plugin"
	}
	if config.HeaderValue == "" {
		config.HeaderValue = "example"
	}
	return nil
}

// onHttpRequestHeaders mutates the request before it reaches the upstream.
func onHttpRequestHeaders(ctx wrapper.HttpContext, config Config, logger log.Log) types.Action {
	ctx.SetHttpRequestHeader(config.HeaderName, config.HeaderValue)
	return types.ActionContinue
}
