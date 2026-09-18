# ServerFlow

Инструмент быстрой и гибкой настройки серверов. Управление 3X-UI, aaPanel, миграция main-серверов, обновление всех компонентов.

## Возможности

- **Настройка нод 3X-UI** - установка, конфигурация (порт, admin, SSL, БД), автоопределение версий
- **Настройка main-сервера** - 3X-UI + aaPanel с автоопределением
- **Миграция main-сервера** - полный перенос данных с обновлением сертификатов и DNS
- **Обновление всего** - пакеты, панели, ядро XRay, Nginx, PHP, MySQL/MariaDB
- **Добавление серверов** через лаунчер (только metadata, без настройки)
- **Автоопределение SSH-ключей** - `ssh/{name}.key` определяется автоматически
- **Автоопределение версий** панелей через SSH

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
├── LAUNCHER.bat         # Bash-лаунчер (Windows)
├── .env                 # Переменные окружения (не в git)
├── .env.example         # Шаблон .env
├── config/
│   └── servers.json     # Лёгкий индекс серверов (метаданные, без секретов)
├── data/
│   └── servers/         # Полные данные серверов: метаданные + секреты (не в git)
├── logs/                # Логи (не в git)
├── scripts/
│   ├── common/
│   │   ├── bootstrap.sh      # Единая точка инициализации (PROJECT_ROOT, .env, STANDALONE)
│   │   ├── logger.sh         # Логирование
│   │   ├── validate.sh       # Валидация (IP, hostname, deps)
│   │   ├── ssh.sh            # SSH: подключение, запуск, авто-ключи, версии панелей
│   │   ├── install.sh        # Установка 3X-UI / aaPanel
│   │   ├── config_3xui.sh    # Конфигурация 3X-UI + сохранение секретов
│   │   └── config_aapanel.sh # Конфигурация aaPanel
│   ├── main/
│   │   ├── update_main.sh    # Обновление main-сервера
│   │   ├── backup_all.sh     # Бэкап main
│   │   └── restore_all.sh    # Восстановление main
│   ├── migrate/
│   │   ├── precheck.sh       # Предпроверка миграции
│   │   ├── sync_data.sh      # Синхронизация данных
│   │   ├── update_certs.sh   # Обновление сертификатов
│   │   └── full_migrate.sh   # Полная миграция
│   ├── dns/
│   │   └── update_records.py # DNS обновление (hostkey API)
│   └── admin/
│       ├── add_server.sh     # Добавление сервера (metadata + secrets)
│       └── update_all.sh     # Обновление всех серверов
└── ssh/                 # SSH-ключи {name}.key (не в git)
```

## Двойной режим запуска

### SSH standalone (на сервере)

Скопируйте проект на сервер, затем `cd` в директорию проекта:

```bash
cd /path/to/ServerFlow
bash scripts/common/setup_node.sh mynode 1.2.3.4 root
```

Автоматическое определение: если `/etc/x-ui/` существует - скрипт работает напрямую без SSH.

### Через лаунчер

```bash
bash LAUNCHER.sh → пункт 1
```

## Конфигурация

Скопируйте `.env.example` в `.env` и заполните:

```bash
cp .env.example .env
```

## Архитектура

### Единая инициализация

Все скрипты используют `scripts/common/bootstrap.sh` - единая точка:
- Определение `PROJECT_ROOT`
- Загрузка `.env`
- Инициализация логирования
- Обнаружение standalone-режима (`/etc/x-ui/`)
- Функции управления серверами (`server_exists`, `list_servers`, `load_server_config`)

### Модель данных

`data/servers/{name}.json` - единый источник правды:
```json
{
    "type": "node",
    "host": "1.2.3.4",
    "ssh_user": "root",
    "ssh_password": "secret",
    "ssh_key_path": "ssh/node.key",
    "panels": {
        "3x-ui": { "url": "...", "port": "...", "admin_user": "..." }
    }
}
```

`config/servers.json` - лёгкий индекс для git-отслеживания (без секретов):
```json
{ "CH": { "type": "node", "host": "1.2.3.4", "ssh_user": "root" } }
```

### Автоопределение

- **SSH-ключи**: `ssh/{name}.key` определяется автоматически в `ssh_init()`
- **Версии панелей**: `ssh_detect_panel_version("3x-ui")` и `ssh_detect_panel_version("aapanel")`
- **Порты и учётные данные**: `config_3xui.sh` запрашивает только при отсутствии на сервере

## Лицензия

MIT - см. [LICENSE](LICENSE)