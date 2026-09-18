# ServerFlow

Инструмент быстрой и гибкой настройки серверов. Управление 3X-UI, aaPanel, миграция main-серверов, обновление всех компонентов.

## Возможности

- **Настройка нод 3X-UI** — установка, базовая конфигурация (БД, порт, пароль, SSL), сохранение секретов
- **Настройка main-сервера** — 3X-UI + aaPanel
- **Миграция main-сервера** — полный перенос данных с обновлением сертификатов и DNS
- **Обновление всего** — пакеты, панели, ядро XRay, Nginx, PHP, MySQL/MariaDB
- **Добавление серверов** через лаунчер (включая панели и секреты)

## Быстрый старт

### Linux

```bash
bash LAUNCHER.sh
```

### Windows

Двойной клик по `LAUNCHER.bat` (требуется Git for Windows или WSL).

## Структура проекта

```
ServerFlow/
├── LAUNCHER.sh          # Shell-лаунчер (Linux)
├── LAUNCHER.bat           # Bash-лаунчер (Windows)
├── config/
│   └── servers.json     # Метаданные серверов
├── data/
│   ├── servers/         # Секреты серверов (не в git)
│   └── scripts.json     # Реестр скриптов
├── logs/                # Логи: logs/{name}/{datetime}.log
├── scripts/
│   ├── common/          # ssh.sh, validate.sh, logger.sh, install.sh, config_3xui.sh, config_aapanel.sh, setup_node.sh, setup_main.sh, update_node.sh
│   ├── main/            # update_main.sh, backup_all.sh, restore_all.sh
│   ├── migrate/         # precheck.sh, sync_data.sh, update_certs.sh, full_migrate.sh
│   ├── dns/             # update_records.py (hostkey API)
│   └── admin/           # add_server.sh, update_all.sh
└── .env                 # Переменные окружения (не в git)
```

## Двойной режим запуска скриптов

Каждый скрипт работает и standalone через SSH, и через лаунчер:

### SSH standalone (на сервере)

Скопируйте проект на сервер, затем `cd` в директорию проекта:

```bash
# На сервере:
cd /path/to/ServerFlow
bash scripts/common/setup_node.sh mynode 1.2.3.4 root
```

Автоматическое определение: если `/etc/x-ui/` существует — скрипт работает напрямую без SSH.

### Через лаунчер

```bash
bash LAUNCHER.sh → пункт 1
```

## Конфигурация

Скопируйте `.env.example` в `.env` и заполните:

```bash
cp .env.example .env
```

## Лицензия

MIT — см. [LICENSE](LICENSE)
