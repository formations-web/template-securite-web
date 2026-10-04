CERT_NAME := caddy-root.crt
CERT_SRC  := caddy:/data/caddy/pki/authorities/local/root.crt
TMP_CERT  := /tmp/$(CERT_NAME)

.PHONY: setup install_cert dev stop_dev sh cp_env  install_dependencies build_app

setup: cp_env
	$(MAKE) dev
	$(MAKE) install_cert
	$(MAKE) install_dependencies
	$(MAKE) build_app

cp_env:
	cp .env.example .env

build:
	docker compose exec app npm run build

stop:
	docker compose --profile dev down
	
dev:
	docker compose --profile dev up -d

# Tente d'installer le certificat sur le poste
install_cert:
	@echo "Attente du certificat Caddy..."
	@for i in $$(seq 1 30); do \
		docker compose cp $(CERT_SRC) $(TMP_CERT) 2>/dev/null && break; \
		sleep 1; \
	done; \
	[ -f $(TMP_CERT) ] || { echo "Certificat introuvable." >&2; exit 1; }
	@set -e; trap 'rm -f $(TMP_CERT)' EXIT; \
	if command -v update-ca-certificates >/dev/null 2>&1; then \
		echo "Debian/Ubuntu détecté"; \
		sudo cp $(TMP_CERT) /usr/local/share/ca-certificates/$(CERT_NAME); \
		sudo update-ca-certificates; \
	elif command -v trust >/dev/null 2>&1; then \
		echo "Arch/Fedora/RHEL détecté"; \
		sudo trust anchor --store $(TMP_CERT); \
	else \
		echo "Distribution non supportée : installez le certificat manuellement." >&2; \
		exit 1; \
	fi

install_dependencies:
	docker compose exec app npm ci
	docker compose exec app composer i

build_app:
	docker compose exec app npm run build

sh:
	docker compose exec -it app /bin/sh

# Supprime aussi le fichier de HMR laissé lors de l'arrêt brutal de Vite
stop_dev:
	docker compose down vite
	rm -f src/public/hot 