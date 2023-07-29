.PHONY: test lint-chart lint-config clean-example-outputs generate-example-outputs regenerate-example-outputs
SHELL := /bin/bash

INPUT_FILES = $(wildcard examples/*/values.yaml)
OTEL_INPUT_FILES = $(subst values.yaml,otel-collector-values.yaml,$(INPUT_FILES))
OUTPUT_FILES = $(subst values.yaml,output.yaml,$(INPUT_FILES))
OTEL_OUTPUT_FILES = $(subst otel-collector-values.yaml,otel-collector-output.yaml,$(OTEL_INPUT_FILES))
METRIC_CONFIG_FILES = $(subst values.yaml,metrics.river,$(INPUT_FILES))
OTEL_METRIC_CONFIG_FILES = $(subst otel-collector-values.yaml,otel-collector-metrics.yaml,$(OTEL_INPUT_FILES))
LOG_CONFIG_FILES = $(subst values.yaml,logs.river,$(INPUT_FILES))
OTEL_LOG_CONFIG_FILES = $(subst otel-collector-values.yaml,otel-collector-logs.yaml,$(OTEL_INPUT_FILES))

CT_CONFIGFILE ?= .github/configs/ct.yaml
LINT_CONFIGFILE ?= .github/configs/lintconf.yaml

lint-chart:
	ct lint --debug --config "$(CT_CONFIGFILE)" --lint-conf "$(LINT_CONFIGFILE)" --check-version-increment=false

lint-config: scripts/lint-configs.sh
	./scripts/lint-configs.sh $(METRIC_CONFIG_FILES) $(LOG_CONFIG_FILES)

test: scripts/test-runner.sh lint-chart lint-config
	./scripts/test-runner.sh --show-diffs

install-deps: scripts/install-deps.sh
	./scripts/install-deps.sh

# Grafana Agent generated files
%/output.yaml: %/values.yaml
	helm template k8smon charts/k8s-monitoring -f $< > $@

%/metrics.river: %/output.yaml
	yq -r "select(.metadata.name==\"k8smon-grafana-agent\") | .data[\"config.river\"] | select( . != null )" $< > $@

%/logs.river: %/output.yaml
	yq -r "select(.metadata.name==\"k8smon-grafana-agent-logs\") | .data[\"config.river\"] | select( . != null )" $< > $@

# OpenTelemetry Collector generated files
%/otel-collector-values.yaml: %/values.yaml
	yq --yaml-output '.["grafana-agent"].enabled=false | .["grafana-agent-logs"].enabled=false | .["opentelemetry-collector"].enabled=true | .["opentelemetry-collector-logs"].enabled=true' $< > $@

%/otel-collector-output.yaml: %/otel-collector-values.yaml
	helm template k8smon charts/k8s-monitoring -f $< > $@

%/otel-collector-metrics.yaml: %/otel-collector-output.yaml
	yq -r "select(.metadata.name==\"grafana-k8s-monitoring-config\") | .data[\"relay.yaml\"] | select( . != null )" $< > $@

#%/otel-collector-logs.yaml: %/otel-collector-output.yaml
#	yq -r "select(.metadata.name==\"k8smon-grafana-agent-logs\") | .data[\"config.river\"] | select( . != null )" $< > $@

clean-example-outputs:
	rm -f $(METRIC_CONFIG_FILES) $(LOG_CONFIG_FILES) $(OTEL_INPUT_FILES) $(OTEL_METRIC_CONFIG_FILES) $(OTEL_LOG_CONFIG_FILES)

generate-agent-configs: $(METRIC_CONFIG_FILES) $(LOG_CONFIG_FILES)

generate-otel-configs: $(OTEL_METRIC_CONFIG_FILES)

#clean-example-outputs:
#	rm -f $(OUTPUT_FILES)

generate-example-outputs: $(OUTPUT_FILES) $(OTEL_INPUT_FILES) $(OTEL_OUTPUT_FILES)

regenerate-example-outputs: clean-example-outputs generate-example-outputs generate-agent-configs generate-otel-configs
