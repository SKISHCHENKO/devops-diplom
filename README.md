# Дипломный практикум в Yandex Cloud

## Цели:

- Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
- Запустить и сконфигурировать Kubernetes кластер.
- Установить и настроить систему мониторинга.
- Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
- Настроить CI для автоматической сборки и тестирования.
- Настроить CD для автоматического развёртывания приложения.

## Этапы выполнения:

### Создание облачной инфраструктуры

Ожидаемые результаты:

- Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий, стейт основной конфигурации сохраняется в бакете или Terraform Cloud
- Полученная конфигурация инфраструктуры является предварительной, поэтому в ходе дальнейшего выполнения задания возможны изменения.

### Создание Kubernetes кластера

Ожидаемый результат:

- Работоспособный Kubernetes кластер.
- В файле ~/.kube/config находятся данные для доступа к кластеру.
- Команда kubectl get pods --all-namespaces отрабатывает без ошибок.

### Создание тестового приложения

Ожидаемый результат:

- Git репозиторий с тестовым приложением и Dockerfile.
- Регистр с собранным docker image. В качестве регистри может быть DockerHub или Yandex Container Registry, созданный также с помощью terraform.

### Подготовка cистемы мониторинга и деплой приложения

Ожидаемый результат:

- Git репозиторий с конфигурационными файлами для настройки Kubernetes.
- Http доступ на 80 порту к web интерфейсу grafana.
- Дашборды в grafana отображающие состояние Kubernetes кластера.
- Http доступ на 80 порту к тестовому приложению.
- Atlantis или terraform cloud или ci/cd-terraform

### Установка и настройка CI/CD

Ожидаемый результат:

- Интерфейс ci/cd сервиса доступен по http.
- При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
- При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.

### Что необходимо для сдачи задания?

- Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
- Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
- Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
- Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
- Репозиторий с конфигурацией Kubernetes кластера.
- Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
- Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)

## Выполнение

Один GitHub-репозиторий со всей работой: Terraform, Ansible, Kubernetes,
мониторинг, nginx-приложение и оба GitHub Actions workflow. Все команды ниже
выполняются из корня этого репозитория, если явно не указан другой каталог.

**Состояние на 05.11.2026.** Проверен публичный репозиторий и его актуальный коммит main [`aab6651`](https://github.com/SKISHCHENKO/devops-diplom/commit/aab6651f722cf4bcc0f8adb2388d601e03495a54) от 27.10.2026. Terraform CI и CI приложения для этого коммита завершились успешно. В этих запусках jobs `apply` и `deploy` пропущены; для тега `v0.0.1-ci` подтверждены сборка и публикация, а `deploy` тоже пропущен. Живой Kubernetes, мониторинг и CD требуют отдельного подтверждения после развёртывания. Прямые ссылки и опубликованные digest приведены в [отчёте для сдачи](#отчет-для-сдачи).

## Содержание

1. [Что разворачивается](#что-разворачивается)
2. [Структура репозитория](#структура-репозитория)
3. [Инструменты](#инструменты)
4. [Профиль Yandex CLI и локальные параметры](#профиль-yandex-cli-и-локальные-параметры)
5. [Создание сервисных аккаунтов и S3 backend](#создание-сервисных-аккаунтов-и-s3-backend)
   - [Проверка плана без создания ВМ](#проверка-плана-без-создания-вм)
6. [Один GitHub-репозиторий и его секреты](#один-github-репозиторий-и-его-секреты)
7. [Первый push и сборка приложения](#первый-push-и-сборка-приложения)
8. [Установка Kubernetes](#установка-kubernetes)
9. [Мониторинг и первоначальный деплой](#мониторинг-и-первоначальный-деплой)
10. [CD по тегу](#cd-по-тегу)
11. [Работа обоих workflow](#работа-обоих-workflow)
12. [Локальная проверка приложения и конфигураций](#локальная-проверка-приложения-и-конфигураций)
13. [Повторное создание и удаление](#повторное-создание-и-удаление)
14. [Отчет для сдачи](#отчет-для-сдачи)
15. [Скриншоты для сдачи](#скриншоты-для-сдачи)

## Что разворачивается

Terraform создаёт одну VPC, три подсети в двух зонах доступности (`ru-central1-a` и `ru-central1-d`), одну security group, три статических публичных IPv4-адреса и три ВМ Ubuntu 22.04. Ansible устанавливает K3s `v1.36.5+k3s1` (Kubernetes 1.36.5): один управляющий узел и два рабочих. Встроенный Traefik принимает HTTP на порту 80.

| Узел | Зона | Подсеть / внутренний IP | vCPU / гарантированная доля | RAM | SSD | Прерываемый |
|---|---|---|---|---|---|---|
| control-plane | ru-central1-a | `a`: `10.10.10.0/24` / `10.10.10.10` | 2 / 20% | 4 ГиБ | 32 ГиБ | нет |
| worker-1 | ru-central1-d | `d1`: `10.10.20.0/24` / `10.10.20.10` | 2 / 20% | 2 ГиБ | 20 ГиБ | да |
| worker-2 | ru-central1-d | `d2`: `10.10.30.0/24` / `10.10.30.10` | 2 / 20% | 2 ГиБ | 20 ГиБ | да |

`d1` и `d2` — ключи двух разных подсетей в одной зоне `ru-central1-d`. Все ВМ используют платформу `standard-v3`; каждой ВМ выделяется отдельный статический публичный IP.

Потребность по зонам и квоты, подтверждённые предоставленным выводом Yandex CLI и согласованиями от 27.10.2026:

| Зона | vCPU: нужно / квота | RAM: нужно / квота | SSD: нужно / квота |
|---|---|---|---|
| ru-central1-a | 2 / 2 | 4 / 16 ГиБ | 32 / 32 ГиБ |
| ru-central1-d | 4 / 4 | 4 / 16 ГиБ | 40 / 40 ГиБ |

Для выбранного варианта с самостоятельной установкой Kubernetes через Ansible используются три ВМ и подсети в разных зонах `a` и `d`.

В Kubernetes устанавливаются:

- nginx-приложение с двумя репликами, Service и Ingress;
- Prometheus Operator и Prometheus;
- Grafana со встроенными Kubernetes dashboards и дашбордом «Диплом — Kubernetes»;
- Alertmanager, node-exporter и kube-state-metrics.

Постоянные компоненты мониторинга и их локальные тома закреплены за непрерываемым `control-plane`. Учебный кластер использует один управляющий узел.

| Интерфейс | Адрес |
|---|---|
| Приложение | `http://<IP_control-plane>/` |
| Проверка здоровья приложения | `http://<IP_control-plane>/healthz` |
| Версия приложения | `http://<IP_control-plane>/version.txt` |
| Grafana | `http://<IP_control-plane>/grafana/` |
| CI/CD | вкладка Actions общего GitHub-репозитория |

После развёртывания приложение и Grafana должны быть доступны по HTTP на **80 порту**. Фактические публичные URL в отчёте заполняются после проверки этих интерфейсов. Образ приложения хранится в Docker Hub. Это реестр Docker-образов, а не второй Git-репозиторий с исходниками.

## Структура репозитория

| Путь | Назначение |
|---|---|
| [README.md](README.md) | Описание работы |
| [terraform/bootstrap/](terraform/bootstrap/) | сервисные аккаунты, их ключи и приватный бакет S3 |
| [terraform/cluster/](terraform/cluster/) | основной Terraform-стек с S3 backend: сеть и три ВМ |
| [ansible/site.yml](ansible/site.yml) | подготовка ОС, установка K3s и получение kubeconfig |
| [ansible/templates/](ansible/templates/) | конфигурации K3s server и agent |
| [kubernetes/app/](kubernetes/app/) | Namespace, Deployment, Service и Ingress приложения |
| [kubernetes/monitoring/](kubernetes/monitoring/) | параметры Helm, Ingress Grafana и дашборд |
| [kubernetes/rbac/](kubernetes/rbac/) | ограниченный доступ GitHub Actions к Deployment |
| [app/Dockerfile](app/Dockerfile) | сборка nginx-образа |
| [app/nginx.conf](app/nginx.conf) | раздача статики, health endpoint и версия |
| [app/html/index.html](app/html/index.html) | тестовая страница приложения |
| [app/scripts/test.sh](app/scripts/test.sh) | проверка nginx и HTTP в Docker |
| [scripts/](scripts/) | bootstrap, создание кластера, деплой, проверки и удаление |
| [.github/workflows/terraform.yml](.github/workflows/terraform.yml) | проверка Terraform и автоматический apply при коммитах main |
| [.github/workflows/app.yml](.github/workflows/app.yml) | сборка, тестирование и публикация образа; деплой по тегу |
| [.env.example](.env.example) | образец локальных параметров |
| [.gitignore](.gitignore) | исключения для state, ключей, локальных настроек и временных файлов |
| [requirements.txt](requirements.txt) | зависимости Ansible и локальных проверок |

Каталоги `.secrets/`, `.generated/`, `.venv/`, файлы state и `.env` создаются локально при запуске и исключены из Git. Bootstrap state содержит созданные ключи. При передаче исходников отдельно исключайте `.env`, `.secrets/`, `.generated/`, `.terraform/` и state-файлы: архиватор не применяет `.gitignore` автоматически.

## Инструменты

Рабочий компьютер — Linux/bash; под Windows можно использовать WSL Ubuntu. Три ВМ Kubernetes создаются Terraform в Yandex Cloud на этапе развёртывания.

Нужны Python 3.10+, Git, curl, unzip, OpenSSL, Yandex CLI, Terraform 1.12.2, kubectl 1.36 и Helm 3 или 4. В обоих jobs Terraform workflow также закреплена версия 1.12.2; установленный локально Terraform 1.12.2 переустанавливать не нужно. Для локального теста приложения нужен Docker; GitHub
runner собирает и тестирует образ своим Docker.

Базовые пакеты Ubuntu 22.04/24.04:

```bash
sudo apt-get update
sudo apt-get install -y git curl unzip openssl python3-venv
```

Установка Terraform для Linux x86_64:

```bash
(
  set -e
  mkdir -p /tmp/diplom-terraform
  cd /tmp/diplom-terraform
  curl -fSLO https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip
  curl -fSLO https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_SHA256SUMS
  grep '  terraform_1.12.2_linux_amd64.zip$' terraform_1.12.2_SHA256SUMS | sha256sum -c -
  unzip terraform_1.12.2_linux_amd64.zip
  sudo install -m 0755 terraform /usr/local/bin/terraform
)
```

Установка kubectl для Linux x86_64:

```bash
curl -fsSLo kubectl https://dl.k8s.io/release/v1.36.5/bin/linux/amd64/kubectl
curl -fsSLo kubectl.sha256 https://dl.k8s.io/release/v1.36.5/bin/linux/amd64/kubectl.sha256
echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c -
sudo install -m 0755 kubectl /usr/local/bin/kubectl
```

Helm: [официальная инструкция установки](https://helm.sh/docs/intro/install/).
Yandex CLI: [инструкция Yandex Cloud](https://yandex.cloud/ru/docs/cli/operations/install-cli).

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
terraform version
ansible-playbook --version
kubectl version --client
helm version
```

## Профиль Yandex CLI и локальные параметры

| Параметр | Значение |
|---|---|
| Облако | `cloud-userg` |
| Cloud ID | `b1ghf5g8o4mhdlrvofo5` |
| Каталог | `netology-userg` |
| Folder ID | `b1gcaq8clab0al7c1qhs` |
| Профиль CLI | `default` |

```bash
yc config profile list
yc --profile default config get cloud-id
yc --profile default config get folder-id
```

Bootstrap использует `YC_PROFILE=default` из `.env` и передаёт `--profile` явно, не переключая активный профиль пользователя. Основной Terraform и GitHub Actions используют ключ созданного сервисного аккаунта, а не пользовательский профиль CLI. Облако и каталог основного стека задаются в `config.auto.tfvars.json` и секрете `TFVARS_JSON`.

```bash
test -f .env || cp .env.example .env
nano .env
```

| Поле | Что указать |
|---|---|
| `YC_PROFILE` | `default` — подтверждённый профиль для этой работы |
| `ADMIN_CIDR` | внешний IPv4 рабочего компьютера с маской `/32` |
| `SSH_PUBLIC_KEY_PATH` | `$HOME/.ssh/id_ed25519.pub` |
| `IMAGE_NAME` | `<skishchenko>/devops-diplom-app`, строчными буквами |
| `IMAGE_TAG` | `main` для первоначального запуска |

## Создание сервисных аккаунтов и S3 backend

Это первый этап развёртывания. Он выполняется локально от пользовательского профиля Yandex CLI до настройки автоматического Terraform pipeline.

```bash
bash scripts/bootstrap.sh
```

Пользователю выбранного профиля нужны права создания сервисных аккаунтов, их ключей, назначения IAM-ролей и управления Object Storage, включая ACL.
Скрипт проверяет cloud/folder, создаёт ресурсы bootstrap и инициализирует S3 backend основного стека.

| Созданный объект | Назначение и права |
|---|---|
| Terraform SA | `compute.editor` и `vpc.admin` в выбранном каталоге |
| Авторизованный ключ Terraform SA | доступ основного Terraform к API Yandex Cloud |
| S3 SA и статический ключ | ACL `FULL_CONTROL` только на бакет состояния; IAM-ролей на каталог нет |
| Приватный версионируемый бакет | хранение `cluster/terraform.tfstate` |

У Terraform SA нет общей роли суперпользователя `admin` или `editor` на всё облако. Его ключ не передаётся ВМ. Учётные данные для API Yandex Cloud и S3 backend разделены.

Скрипт сохраняет локально:

- `.secrets/terraform-sa.json` — JSON-ключ Terraform SA;
- `.secrets/s3.json` — ключи S3 backend;
- `terraform/cluster/config.auto.tfvars.json` — параметры основного стека;
- `terraform/cluster/backend.hcl` — параметры S3 backend без ключей.

Bootstrap state находится в `terraform/bootstrap/terraform.tfstate` и содержит созданные ключи.  Основной state находится в S3. Эти локальные файлы исключены из Git.

### Проверка плана без создания ВМ

```bash
source .venv/bin/activate
bash <<'CHECK_PLAN'
set -euo pipefail
source scripts/common.sh
load_credentials
cluster_init
terraform -chdir=terraform/cluster fmt -check
terraform -chdir=terraform/cluster validate
terraform -chdir=terraform/cluster plan -input=false
CHECK_PLAN
```

Этот блок выполняет init, validate и plan, без apply.

В предоставленном логе от 27.10.2026 backend S3 инициализирован, `validate` завершился сообщением `Success! The configuration is valid.`, план содержит `11 to add, 0 to change, 0 to destroy`: три ВМ, три статических IP, три подсети, одну VPC и одну security group. Загрузочные диски 32/20/20 ГиБ входят в ресурсы ВМ. Создание ресурсов и готовность Kubernetes этим логом ещё не подтверждены.

## Один GitHub-репозиторий и его секреты

Общий GitHub-репозиторий: <https://github.com/SKISHCHENKO/devops-diplom>.

В Docker Hub создано публичное хранилище образов `devops-diplom-app`. Для аккаунта `skishchenko` полное имя образа — `skishchenko/devops-diplom-app`.
 Публичный доступ позволяет Kubernetes скачивать образ без дополнительного imagePullSecret.

В **GitHub-репозитории**  → Settings → Secrets and variables → Actions.

| Тип | Имя | Источник значения | Когда добавить |
|---|---|---|---|
| Variable | `IMAGE_NAME` | `skishchenko/devops-diplom-app` | до первого push |
| Variable | `TF_APPLY_ENABLED` | `false` при подготовке; `true` перед созданием ВМ | до первого push |
| Variable | `K8S_DEPLOY_ENABLED` | `false` до готовности кластера; затем `true` | до первого push |
| Variable | `TF_STATE_BUCKET` | вывод `terraform -chdir=terraform/bootstrap output -raw bucket_name` | до включения `TF_APPLY_ENABLED` |
| Secret | `DOCKERHUB_USERNAME` | `skishchenko` — логин Docker Hub | до первого push |
| Secret | `DOCKERHUB_TOKEN` | токен Docker Hub с правом записи образа | до первого push |
| Secret | `YC_SA_KEY_JSON` | весь JSON `.secrets/terraform-sa.json` | до включения `TF_APPLY_ENABLED` |
| Secret | `AWS_ACCESS_KEY_ID` | поле `access_key` из `.secrets/s3.json` | до включения `TF_APPLY_ENABLED` |
| Secret | `AWS_SECRET_ACCESS_KEY` | поле `secret_key` из `.secrets/s3.json` | до включения `TF_APPLY_ENABLED` |
| Secret | `TFVARS_JSON` | весь JSON `terraform/cluster/config.auto.tfvars.json` | до включения `TF_APPLY_ENABLED` |
| Secret | `KUBE_CONFIG_B64` | содержимое `.secrets/ci-kubeconfig.b64` | после установки приложения, до включения CD |

`TFVARS_JSON` содержит публичный SSH-ключ и параметры ВМ. Закрытый SSH-ключ и административный kubeconfig в GitHub не загружаются. Bootstrap не запускается из workflow: основной Terraform использует подготовленные SA и бакет.

На этапе подготовки без ВМ достаточно `IMAGE_NAME`, двух переменных со значением `false` и секретов `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN`. `TF_STATE_BUCKET` и облачные секреты добавляются до включения `TF_APPLY_ENABLED`. `KUBE_CONFIG_B64` добавляется после первоначального деплоя, до включения CD.

## Первый push и сборка приложения

Первый push запускает два workflow одного репозитория:

1. **Terraform CI-CD** проверяет конфигурации. При `TF_APPLY_ENABLED=false`
   job `apply` пропускается; сеть и ВМ не создаются. При значении `true`
   выполняются plan/apply основного стека.
2. **Application CI-CD** собирает Docker-образ из `app/`, проверяет nginx и HTTP,
   публикует `<IMAGE_NAME>:main` и `sha-<полный_commit>`.

Сначала должны успешно пройти проверки и публикация образа. Пропущенный `apply` в режиме подготовки ожидаем; такой запуск не подтверждает выполнение Terraform CD.
Первый коммит main не требует `KUBE_CONFIG_B64`: CD выполняется по тегу только при `K8S_DEPLOY_ENABLED=true`.

## Установка Kubernetes

```bash
bash scripts/cluster.sh
export KUBECONFIG="$PWD/.generated/admin.kubeconfig"
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

Скрипт использует тот же S3 state, выполняет Terraform apply, генерирует inventory из актуальных outputs и запускает Ansible. Если предыдущий workflow уже создал ВМ, повторного создания неизменённых ресурсов не требуется.

Ansible подготавливает ОС, устанавливает K3s `v1.36.5+k3s1` и ждёт три узла Ready. Плейбук рассчитан на новую установку или повторный запуск этой minor-ветки;
существующая установка другой ветки останавливает выполнение до изменения конфигурации. Для её обновления требуется отдельный поэтапный план.
Kubeconfig записывается в `.generated/admin.kubeconfig` и `~/.kube/config`. Предыдущий `~/.kube/config`, если он существовал, сохраняется рядом как `config.before-diplom-*`.

## Мониторинг и первоначальный деплой

Образ `<IMAGE_NAME>:main` уже должен быть опубликован первым workflow приложения.

```bash
bash scripts/deploy.sh
bash scripts/verify.sh
python3 - <<'SHOW_URLS'
import json
from pathlib import Path
outputs = json.loads(Path('.generated/outputs.json').read_text())
print('Приложение:', outputs['app_url']['value'])
print('Grafana:', outputs['grafana_url']['value'])
SHOW_URLS
```

`deploy.sh` устанавливает `kube-prometheus-stack` версии chart `92.10.1`, создаёт секрет Grafana, Ingress и дашборд, затем разворачивает приложение из `IMAGE_NAME:IMAGE_TAG`. `verify.sh` проверяет готовность узлов и компонентов, HTTP приложения/Grafana и наличие метрики трёх Ready-узлов в Prometheus.

Для Grafana логин — `admin`, пароль хранится в `.secrets/grafana-password`:

```bash
cat .secrets/grafana-password
```

Параметры мониторинга сохраняются при переносе workers в зону `d`: привязка постоянных компонентов идёт по имени `control-plane`, а не по зоне. Работу мониторинга в живом кластере нужно подтвердить после установки: успешный Terraform plan её не проверяет.

В K3s используются SQLite и встроенные компоненты управления. Отдельные scrape jobs для etcd, controller-manager, scheduler и kube-proxy отключены. Включены метрики API, kubelet/cAdvisor, узлов и объектов Kubernetes.

В Grafana откройте «Диплом — Kubernetes»: Ready-узлы, Running-pod, CPU и RAM. Также доступны встроенные Kubernetes dashboards.

SSH разрешён с `ADMIN_CIDR`. Kubernetes API доступен на 6443 для внешних GitHub runners с проверкой CA и RBAC. Внутренний обмен разрешён участникам общей security group; VXLAN не открыт всему Интернету.

При повторном `deploy.sh` снова применяется образ из `IMAGE_NAME:IMAGE_TAG`. После релиза надо обновить `IMAGE_TAG` в `.env`, если планируется повторно запускать этот скрипт, чтобы случайно не вернуть приложение к образу `main`.

## CD по тегу

При первоначальном деплое создаётся ServiceAccount `github-deployer`. Его kubeconfig находится в `.secrets/ci.kubeconfig`, а base64-версия — в `.secrets/ci-kubeconfig.b64`. Вставьте содержимое второго файла в секрет `KUBE_CONFIG_B64` того же GitHub-репозитория.

После этого можно задать repository variable `K8S_DEPLOY_ENABLED=true`. До её включения теги собираются и публикуются, а job `deploy` пропускается.

Этот аккаунт может обновлять только Deployment `diplom-web` в namespace `app`. Административного доступа к кластеру у CD нет.

```bash
git tag v1.0.0
git push origin v1.0.0
```

Workflow приложения соберёт и протестирует образ, опубликует тег `v1.0.0` с OCI version label и обновит Deployment по неизменяемому digest. После успешного rollout `/version.txt` должен возвращать `v1.0.0`.

Для демонстрации следующего обновления надо изменить `app/html/index.html`, сделать commit/push и создать новый тег, например `v1.0.1`.

## Работа обоих workflow

| Событие в общем репозитории | Terraform CI-CD | Application CI-CD |
|---|---|---|
| Коммит main, включая README | проверки; plan/apply при `TF_APPLY_ENABLED=true` | сборка, HTTP-тест и публикация образа |
| Коммит другой ветки | автоматически не запускается | сборка, HTTP-тест и публикация образа |
| Pull request в main | проверки без облачных секретов | CI запускается при push исходной ветки |
| Push тега, например v1.0.0 | не запускается | сборка, тест, публикация; CD по digest при `K8S_DEPLOY_ENABLED=true` |
| Ручной Run workflow | проверки; apply разрешён только на main при включённой переменной | сборка/публикация; CD только для тега при включённой переменной |

У Terraform workflow нет `paths`-фильтра: после включения `TF_APPLY_ENABLED=true` автоматический apply при любом коммите main соответствует выбранной в задании альтернативе Atlantis/Terraform Cloud. Для окончательной сдачи обе переменные должны быть включены и подтверждены реальными запусками; подготовительный
режим с пропущенными apply/deploy не завершает эти пункты задания. У workflow приложения тоже нет фильтра по каталогу: CI работает при каждом коммите, хотя Docker build context ограничен `app/`.

Bootstrap и установка Kubernetes выполняются локальными скриптами. Terraform pipeline управляет сетью и ВМ. После замены ВМ повторите `cluster.sh` и `deploy.sh`; для неизменённых ВМ повторная установка не нужна.

В выбранном S3 backend нет распределённой блокировки. Только job `apply` сериализован группой `terraform-cluster`: `cancel-in-progress: false` сохраняет работающий apply, а `queue: max` позволяет ожидать нескольким запускам вместо замены единственного ожидающего. Проверки PR и main выполняются независимо от этой очереди и не вытесняют ожидающий apply. Для CD приложения используется отдельная очередь `app-production-deploy` с теми же параметрами. GitHub допускает до 100 ожидающих jobs в такой очереди; порядок ожидания не гарантирует порядок создания коммитов или тегов. Параметры очереди описаны в [официальной документации GitHub](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency). Локальные apply/destroy запускайте после завершения активного workflow, чтобы не изменять один state из двух процессов одновременно.

GitHub Actions предоставляет веб-интерфейс CI/CD по HTTPS. Отдельная ВМ Jenkins/TeamCity не используется. Приложение и Grafana обслуживаются по HTTP/80, как требуется для этих двух интерфейсов в задании.

## Локальная проверка приложения и конфигураций

Сборка и HTTP-тест приложения из корня репозитория:

```bash
docker build --build-arg APP_VERSION=local --build-arg VCS_REF=local -t diplom-web:test ./app
bash app/scripts/test.sh diplom-web:test
```

Тест проверяет `nginx -t`, `/healthz`, HTML, наличие версии и HTTP 404 для отсутствующего файла. Временный контейнер удаляется после проверки.

Проверка исходников:

```bash
source .venv/bin/activate
bash scripts/validate-local.sh
terraform fmt -check -recursive
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
```

Для отдельной проверки основного Terraform без подключения к S3 надо использовать чистую копию `terraform/cluster/` с `init -backend=false`, затем `validate`.
В рабочем каталоге после bootstrap его backend уже настроен. Workflow выполняет проверку на свежем runner.

Скрипты используют общий кэш Terraform providers: `$HOME/.terraform.d/plugin-cache`. Провайдер скачивается, когда подходящего пакета нет в рабочем каталоге/кэше;
`bootstrap` и основной стек переиспользуют одну копию выбранной версии. Если пакет был установлен в каталогах этого проекта до включения кэша, скрипты сначала перенесут его полную копию в кэш; существующие пакеты кэша не перезаписываются. Проверка контрольных сумм по lock-файлу сохраняется.
Путь можно изменить через `TF_PLUGIN_CACHE_DIR` в `.env` или окружении. GitHub Actions тоже сохраняет и восстанавливает кэш по lock-файлам и платформе. Доступ к registry для метаданных может требоваться и при наличии кэша.

Файлы `.terraform.lock.hcl` сохранены в обоих Terraform-каталогах и фиксируют версию Yandex provider 0.196.0. Их нужно хранить в Git. Workflow выполняет `init -lockfile=readonly`: обычный запуск не меняет выбранные зависимости. Перед использованием облачных ключей job `apply` проверяет наличие обязательных параметров и при отсутствии выводит только их имена. Локальные проверки исходников не подтверждают работу облачного backend, публикацию Docker image или готовность живого кластера. Эти результаты проверяются фактическими запусками pipeline и `scripts/verify.sh`.

## Повторное создание и удаление

Чтобы проверить воспроизводимость основного стека, временно задайте `TF_APPLY_ENABLED=false` и `K8S_DEPLOY_ENABLED=false`, дождитесь завершения активных workflow и выполните:

```bash
bash scripts/destroy.sh
bash scripts/cluster.sh
bash scripts/deploy.sh
bash scripts/verify.sh
```

`destroy.sh` удаляет ВМ, диски, IP и сеть основного стека. Bootstrap и бакет остаются для следующего apply. При пересоздании управляющего узла старые PVC
мониторинга удаляются вместе с его диском.

После пересоздания кластера замените `KUBE_CONFIG_B64` в этом же репозитории новым содержимым `.secrets/ci-kubeconfig.b64`, затем верните `TF_APPLY_ENABLED=true` и `K8S_DEPLOY_ENABLED=true` для демонстрации pipeline. Для окончательного удаления после проверки оставьте обе переменные `false`, дождитесь завершения workflow и запустите только `bash scripts/destroy.sh`. Этот скрипт сохраняет bootstrap и бакет состояния.

## Отчет для сдачи

Проверка публичных результатов выполнена 05.11.2026. Последние запуски main относятся к коммиту [`aab6651`](https://github.com/SKISHCHENKO/devops-diplom/commit/aab6651f722cf4bcc0f8adb2388d601e03495a54) от 27.10.2026. Прямые ссылки ниже ведут на конкретные запуски, а не только на общую вкладку Actions.

| Материал | Ссылка / результат |
|---|---|
| Общий GitHub-репозиторий | <https://github.com/SKISHCHENKO/devops-diplom> |
| Проверенная версия исходников | [`aab6651` — Update deployment configuration and documentation](https://github.com/SKISHCHENKO/devops-diplom/commit/aab6651f722cf4bcc0f8adb2388d601e03495a54), main, 27.10.2026 |
| Terraform | [terraform/](terraform/), отдельно [bootstrap/](terraform/bootstrap/) и [cluster/](terraform/cluster/) |
| Ansible и K3s | [ansible/](ansible/); в конфигурации K3s `v1.36.5+k3s1` |
| Kubernetes и мониторинг | [kubernetes/](kubernetes/); chart `kube-prometheus-stack` `92.10.1` |
| Dockerfile приложения | [app/Dockerfile](app/Dockerfile) |
| Docker Hub repository | <https://hub.docker.com/r/skishchenko/devops-diplom-app> |
| CI-образ из main | `docker.io/skishchenko/devops-diplom-app:main`, опубликован 27.10.2026; [теги Docker Hub](https://hub.docker.com/r/skishchenko/devops-diplom-app/tags) |
| Образ тестового тега | `docker.io/skishchenko/devops-diplom-app:v0.0.1-ci`, опубликован 24.10.2026; сборка и публикация подтверждены, CD пропущен |
| Опубликованный релизный image и тег с CD | Требуется новый релизный тег и успешный job `deploy`; тестовый `v0.0.1-ci` этот результат пока не подтверждает |
| Terraform CI: проверки исходников | [Запуск от push в main](https://github.com/SKISHCHENKO/devops-diplom/actions/runs/40504623352): `validate` — success; Terraform fmt/validate и проверка YAML, HCL, shell, Ansible успешны |
| Terraform pipeline от коммита main с init/plan/apply | В [проверенном запуске](https://github.com/SKISHCHENKO/devops-diplom/actions/runs/40504623352) job `apply` — skipped. Для сдачи нужна ссылка и скриншоты запуска с выполненными облачными init/plan/apply |
| CI приложения: build/test/push | [Успешный запуск main](https://github.com/SKISHCHENKO/devops-diplom/actions/runs/40504623448): сборка, nginx/HTTP-тест и публикация — success; `deploy` — skipped |
| CI приложения по тестовому тегу | [Запуск v0.0.1-ci](https://github.com/SKISHCHENKO/devops-diplom/actions/runs/40111437371): `build` — success; `deploy` — skipped |
| Локальная проверка Docker-образа | По предоставленному выводу `app/scripts/test.sh` для `v0.0.1-ci`: nginx-конфигурация, healthz, HTML, версия и HTTP 404 — OK |
| Bootstrap и удалённый backend | По предоставленным логам bootstrap выполнен; бакет `devops-diplom-state-b1gcaq8clab0al7c1qhs`, backend основного стека S3 инициализирован. Это результат локального запуска, а не job `apply` в GitHub |
| Локальный план основного стека | По предоставленному логу от 27.10.2026: `validate` успешен; `11 to add, 0 to change, 0 to destroy`, ВМ `a/d/d`, SSD 32/20/20 ГиБ, три статических IP |
| CD нового релизного тега | Ожидается успешный `deploy`, rollout и проверка `/version.txt` с новым релизным тегом |
| Приложение HTTP/80 | Фактический URL и HTTP-ответ пока не предоставлены; добавить после `deploy.sh` и `verify.sh` |
| Grafana HTTP/80 | Фактический URL `/grafana/` и работа дашборда пока не подтверждены; добавить после развёртывания |
| Логин Grafana | В конфигурации задан `admin`; вход проверить после установки |
| Пароль Grafana | Генерируется при первом `deploy.sh`, сохраняется в `.secrets/grafana-password`; передать проверяющему отдельно |
| Проверка Kubernetes | Ожидается фактический вывод `kubectl get nodes -o wide`, `kubectl get pods --all-namespaces` и успешный `scripts/verify.sh` |
| Воспроизводимость инфраструктуры | Конфигурация и порядок повторного создания подготовлены; фактический destroy/apply основного стека пока не подтверждён |
| Скриншоты | В проверенном дереве репозитория снимки ещё не добавлены; подготовить по таблице ниже |

### Опубликованные образы

Digest получены из Docker Hub при проверке 05.11.2026. Тег `main` может обновляться при следующих push; digest фиксирует проверенную публикацию.

| Тег | Digest | Коммит сборки |
|---|---|---|
| `main` | `sha256:b95d39a627bda0c2e0d7ed9f6f49ee873382899c48d30508a007229dd4343e60` | [`aab6651`](https://github.com/SKISHCHENKO/devops-diplom/commit/aab6651f722cf4bcc0f8adb2388d601e03495a54) |
| `v0.0.1-ci` | `sha256:67f9e26d60a77796552406e211dd599f190b424ca6940b08fc6814245735fc1c` | [`ec285d9`](https://github.com/SKISHCHENKO/devops-diplom/commit/ec285d98f817bb3573205e83b1e77d278f20de78) |

У опубликованного образа `v0.0.1-ci` дополнительно проверены платформа `linux/amd64` и OCI-метаданные:

- `org.opencontainers.image.version=v0.0.1-ci`;
- `org.opencontainers.image.revision=ec285d98f817bb3573205e83b1e77d278f20de78`;
- `org.opencontainers.image.source=https://github.com/SKISHCHENKO/devops-diplom`.

Тестовый тег относится к коммиту `ec285d9` от 24.10.2026, а опубликованный `main` — к более новому `aab6651` от 27.10.2026. Наличие образа и version label подтверждает сборку и публикацию; автоматическое обновление Kubernetes подтверждается отдельным успешным job `deploy`.

Значения repository variables, наличие облачных секретов GitHub, текущее состояние ВМ в Yandex Cloud и результаты локального Ansible не проверяются через публичный список запусков. Их готовность нужно подтвердить перед платным развёртыванием. Bootstrap и локальный plan в таблице отмечены на основании ранее предоставленных логов.

## Скриншоты для сдачи

В задании явно запрошены снимки выбранного Terraform CI/CD pipeline как альтернативы Atlantis/Terraform Cloud. Фиксированного количества скриншотов для всей работы не указано. Остальные снимки ниже помогают подтвердить результат; они дополняют исходники и живые URL приложения/Grafana.

| Снимок | Действие |
|---|---|
| Terraform pipeline — общий результат | После включения `TF_APPLY_ENABLED` и push в main: workflow, ветка/коммит, успешные `validate` и `apply`. `apply: skipped` не подтверждает Terraform CD. |
| Terraform pipeline — init/plan/apply | Раскрытые шаги успешного запуска: подключение S3 backend, план и `Apply complete!`. При первом создании ожидаются 11 новых ресурсов; последующий apply может показать отсутствие изменений. |
| Kubernetes | После `cluster.sh`: `kubectl get nodes -o wide` с тремя Ready-узлами и `kubectl get pods --all-namespaces` после установки компонентов. |
| Grafana | После `deploy.sh` и `verify.sh`: дашборд «Диплом — Kubernetes», три Ready-узла, CPU и RAM; в адресной строке HTTP URL `/grafana/`. |
| Приложение | После деплоя: страница приложения по HTTP/80 с видимым адресом. |
| Релизный Application pipeline | После push нового тега, например `v1.0.0`: успешные `build` и `deploy`, без skipped. |
| Docker Hub | Страница Tags образа `skishchenko/devops-diplom-app` с тем же релизным тегом. |
| Результат обновления | `kubectl -n app rollout status deployment/diplom-web`, образ Deployment с `@sha256:...` и ответ `/version.txt` с релизным тегом. |

