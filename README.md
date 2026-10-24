# Дипломный практикум в Yandex Cloud

Один GitHub-репозиторий со всей работой: Terraform, Ansible, Kubernetes,
мониторинг, nginx-приложение и оба GitHub Actions workflow. Все команды ниже
выполняются из корня этого репозитория, если явно не указан другой каталог.

В задании отдельный репозиторий nginx-приложения предложен в рекомендуемом
варианте. В этом комплекте по выбранной вами структуре приложение находится
в `app/` общего репозитория. У него общий README, история коммитов, теги и
настройки Actions с инфраструктурой. Отдельный Git-репозиторий приложения
создавать не нужно.

Исходники подготовлены по заданию [«Дипломный практикум в Yandex Cloud»](https://github.com/netology-code/devops-diplom-yandexcloud).
Описание компонентов, порядок запуска, проверки и материалы для сдачи
собраны в этом README. Отдельные файлы с инструкциями для запуска не требуются.
Старые приложенные файлы с бастионом в комплект не включены и не использованы.

**Подготовка без создания ВМ:** начните с раздела
[«Один GitHub-репозиторий и его секреты»](#один-github-репозиторий-и-его-секреты).
В GitHub Actions задайте `TF_APPLY_ENABLED=false` и `K8S_DEPLOY_ENABLED=false`.
При отсутствующих переменных инфраструктура и CD также выключены. Terraform
выполняет проверки без обращения к state, приложение собирается, тестируется
и публикуется в Docker Hub. Локальный `scripts/cluster.sh` создаёт ВМ независимо
от этих переменных; на этапе подготовки он не запускается.

## Содержание

1. [Что разворачивается](#что-разворачивается)
2. [Структура репозитория](#структура-репозитория)
3. [Инструменты](#инструменты)
4. [Профиль Yandex CLI и локальные параметры](#профиль-yandex-cli-и-локальные-параметры)
5. [Создание сервисных аккаунтов и S3 backend](#создание-сервисных-аккаунтов-и-s3-backend)
6. [Один GitHub-репозиторий и его секреты](#один-github-репозиторий-и-его-секреты)
7. [Первый push и сборка приложения](#первый-push-и-сборка-приложения)
8. [Установка Kubernetes](#установка-kubernetes)
9. [Мониторинг и первоначальный деплой](#мониторинг-и-первоначальный-деплой)
10. [CD по тегу](#cd-по-тегу)
11. [Работа обоих workflow](#работа-обоих-workflow)
12. [Локальная проверка приложения и конфигураций](#локальная-проверка-приложения-и-конфигураций)
13. [Повторное создание и удаление](#повторное-создание-и-удаление)
14. [Что предоставить для сдачи](#что-предоставить-для-сдачи)

## Что разворачивается

Terraform создаёт VPC, подсети в трёх зонах доступности, security group,
публичные IP и три ВМ Ubuntu 22.04. Ansible устанавливает K3s `v1.36.5+k3s1` (Kubernetes 1.36.5): один
управляющий узел и два рабочих. Встроенный Traefik принимает HTTP на порту 80.

| Узел | Зона | vCPU / гарантированная доля | RAM | SSD | Прерываемый |
|---|---|---|---|---|---|
| control-plane | ru-central1-a | 2 / 20% | 4 ГБ | 32 ГБ | нет |
| worker-1 | ru-central1-b | 2 / 20% | 2 ГБ | 20 ГБ | да |
| worker-2 | ru-central1-d | 2 / 20% | 2 ГБ | 20 ГБ | да |

В Kubernetes устанавливаются:

- nginx-приложение с двумя репликами, Service и Ingress;
- Prometheus Operator и Prometheus;
- Grafana со встроенными Kubernetes dashboards и дашбордом «Диплом — Kubernetes»;
- Alertmanager, node-exporter и kube-state-metrics.

Постоянные компоненты мониторинга и их локальные тома закреплены за
непрерываемым `control-plane`. Учебный кластер использует один управляющий узел.

| Интерфейс | Адрес |
|---|---|
| Приложение | `http://<IP_control-plane>/` |
| Проверка здоровья приложения | `http://<IP_control-plane>/healthz` |
| Версия приложения | `http://<IP_control-plane>/version.txt` |
| Grafana | `http://<IP_control-plane>/grafana/` |
| CI/CD | вкладка Actions общего GitHub-репозитория |

И приложение, и Grafana доступны по HTTP на **80 порту**.
Образ приложения хранится в Docker Hub. Это реестр Docker-образов, а не второй
Git-репозиторий с исходниками.

## Структура репозитория

| Путь | Назначение |
|---|---|
| [README.md](README.md) | общая инструкция для всей работы |
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

Каталоги `.secrets/`, `.generated/`, `.venv/`, файлы state и `.env` создаются
локально при запуске и исключены из Git. В архиве реальных ключей и токенов нет.

## Инструменты

Рабочий компьютер — Linux/bash; под Windows можно использовать WSL Ubuntu.
Три ВМ Kubernetes создаются Terraform в Yandex Cloud на этапе развёртывания.

Нужны Python 3.10+, Git, curl, unzip, OpenSSL, Yandex CLI, Terraform 1.11.4,
kubectl 1.36 и Helm 3. Для локального теста приложения нужен Docker; GitHub
runner собирает и тестирует образ своим Docker.

Базовые пакеты Ubuntu 22.04/24.04:

```bash
sudo apt-get update
sudo apt-get install -y git curl unzip openssl python3-venv
```

Установка Terraform для Linux x86_64:

```bash
mkdir -p /tmp/diplom-terraform
cd /tmp/diplom-terraform
curl -fSLO https://releases.hashicorp.com/terraform/1.11.4/terraform_1.11.4_linux_amd64.zip
curl -fSLO https://releases.hashicorp.com/terraform/1.11.4/terraform_1.11.4_SHA256SUMS
grep '  terraform_1.11.4_linux_amd64.zip$' terraform_1.11.4_SHA256SUMS | sha256sum -c -
unzip terraform_1.11.4_linux_amd64.zip
sudo install -m 0755 terraform /usr/local/bin/terraform
```

Установка kubectl для Linux x86_64:

```bash
curl -fsSLo kubectl https://dl.k8s.io/release/v1.36.5/bin/linux/amd64/kubectl
curl -fsSLo kubectl.sha256 https://dl.k8s.io/release/v1.36.5/bin/linux/amd64/kubectl.sha256
echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c -
sudo install -m 0755 kubectl /usr/local/bin/kubectl
```

Helm 3: [официальная инструкция установки](https://helm.sh/docs/intro/install/).
Yandex CLI: [инструкция Yandex Cloud](https://yandex.cloud/ru/docs/cli/operations/install-cli).

Локальный kubectl 1.36.4 совместим с выбранной веткой сервера 1.36;
заменять его ради совпадения patch-версии не требуется. В CI установлен kubectl 1.36.5.
Рендеринг мониторинга проверен также Helm 4.2.4; полный запуск компонентов
подтверждается после установки командой `scripts/verify.sh`.

Вернитесь в корень распакованного проекта:

```bash
cd /путь/к/devops-diplom
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
terraform version
ansible-playbook --version
kubectl version --client
helm version
```

## Профиль Yandex CLI и локальные параметры

В `.env.example` учтены использовавшиеся ранее параметры:

| Параметр | Значение |
|---|---|
| Облако | `cloud-userg` |
| Cloud ID | `b1ghf5g8o4mhdlrvofo5` |
| Каталог | `netology-userg` |
| Folder ID | `b1gcaq8clab0al7c1qhs` |
| Профиль CLI | `default`; при необходимости выбрать `yc` |

Проверьте существующие профили:

```bash
yc config profile list
yc --profile default config list
# Если используете профиль yc:
yc --profile yc config list
```

Скрипты передают `--profile` явно, не переключая активный профиль пользователя.
Оба профиля одновременно не требуются. Выберите профиль с нужными cloud/folder.
Если их актуальные ID отличаются, исправьте значения в `.env`.

```bash
cp .env.example .env
nano .env
```

Заполните следующие поля:

| Поле | Что указать |
|---|---|
| `YC_PROFILE` | `default` либо `yc` |
| `ADMIN_CIDR` | внешний IPv4 вашего рабочего компьютера с маской `/32` |
| `SSH_PUBLIC_KEY_PATH` | путь к открытому SSH-ключу, например `$HOME/.ssh/id_ed25519.pub` |
| `SSH_PRIVATE_KEY_PATH` | путь к соответствующему закрытому SSH-ключу |
| `IMAGE_NAME` | `<dockerhub_login>/devops-diplom-app`, строчными буквами |
| `IMAGE_TAG` | `main` для первоначального запуска |

`ADMIN_CIDR` — адрес, видимый в Интернете, а не локальный адрес VirtualBox.
Узнать внешний IPv4 можно командой `curl -4 https://api.ipify.org`; добавьте
к результату `/32`. Например: `203.0.113.25/32`.

Если SSH-ключа ещё нет, создайте его; существующий ключ перезаписывать не нужно:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C 'devops-diplom'
```

## Создание сервисных аккаунтов и S3 backend

При замене Kubernetes 1.34 на 1.36 в исходниках повторять уже успешно
завершённый `bootstrap.sh` не требуется: аккаунты, бакет и Terraform-ресурсы
не менялись. Если bootstrap ещё не выполнялся, он нужен один раз по инструкции ниже.
Для новой установки версия задаётся в `ansible/group_vars/all.yml`; в комплекте
это `v1.36.5+k3s1`. Kubectl в CI — `1.36.5`, схема проверки манифестов — `1.36.0`.
Существующий кластер другой minor-ветки требует отдельного поэтапного обновления;
плейбук останавливает такую попытку до изменения конфигурации.

Это первый этап развёртывания. Он выполняется локально от пользовательского
профиля Yandex CLI до настройки автоматического Terraform pipeline.

```bash
bash scripts/bootstrap.sh
```

Пользователю выбранного профиля нужны права создания сервисных аккаунтов,
их ключей, назначения IAM-ролей и управления Object Storage, включая ACL.
Скрипт проверяет cloud/folder, создаёт ресурсы bootstrap и инициализирует
S3 backend основного стека.

| Созданный объект | Назначение и права |
|---|---|
| Terraform SA | `compute.editor` и `vpc.admin` в выбранном каталоге |
| Авторизованный ключ Terraform SA | доступ основного Terraform к API Yandex Cloud |
| S3 SA и статический ключ | ACL `FULL_CONTROL` только на бакет состояния; IAM-ролей на каталог нет |
| Приватный версионируемый бакет | хранение `cluster/terraform.tfstate` |

У Terraform SA нет общей роли суперпользователя `admin` или `editor` на всё
облако. Его ключ не передаётся ВМ. Учётные данные для API Yandex Cloud и S3 backend
разделены.

Скрипт сохраняет локально:

- `.secrets/terraform-sa.json` — JSON-ключ Terraform SA;
- `.secrets/s3.json` — ключи S3 backend;
- `terraform/cluster/config.auto.tfvars.json` — параметры основного стека;
- `terraform/cluster/backend.hcl` — параметры S3 backend без ключей.

Bootstrap state находится в `terraform/bootstrap/terraform.tfstate` и содержит
созданные ключи. Храните его вместе с `.secrets/` у себя. Основной state находится
в S3. Эти локальные файлы исключены из Git.

## Один GitHub-репозиторий и его секреты

Общий GitHub-репозиторий: <https://github.com/SKISHCHENKO/devops-diplom>.
Его корень должен содержать этот README, `.github/`, `terraform/`, `ansible/`,
`kubernetes/`, `scripts/` и `app/`.

В Docker Hub создайте публичное хранилище образов `devops-diplom-app`.
Для аккаунта `skishchenko` полное имя образа — `skishchenko/devops-diplom-app`.
Это значение должно совпадать с `IMAGE_NAME`
в локальном `.env` и в GitHub Actions. Публичный доступ позволяет Kubernetes
скачивать образ без дополнительного imagePullSecret.

Если хранилище ещё не создано, откройте Docker Hub → My Hub → Repositories
→ Create repository, выберите свой namespace, имя `devops-diplom-app` и Public.
В Docker Home откройте Account settings → Personal access tokens → Generate
new token. Выберите Repo Read & Write и сохраните токен для GitHub Actions.
Сборку выполняет GitHub runner, поэтому для этого этапа Docker на локальном
компьютере не требуется.

В **этом же GitHub-репозитории** откройте Settings → Secrets and variables → Actions.

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

Переменные добавляются во вкладке Variables, секреты — во вкладке Secrets.
Имя секрета логина должно быть именно `DOCKERHUB_USERNAME`: workflow читает
`secrets.DOCKERHUB_USERNAME`. Секрет с именем `DOCKERHUB_NAME` его не заменяет.

`TFVARS_JSON` содержит публичный SSH-ключ и параметры ВМ. Закрытый SSH-ключ
и административный kubeconfig в GitHub не загружаются. Bootstrap не запускается
из workflow: основной Terraform использует подготовленные SA и бакет.

На этапе подготовки без ВМ достаточно `IMAGE_NAME`, двух переменных со
значением `false` и секретов `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN`.
`TF_STATE_BUCKET` и облачные секреты добавляются до включения `TF_APPLY_ENABLED`.
`KUBE_CONFIG_B64` добавляется после первоначального деплоя, до включения CD.

## Первый push и сборка приложения

После настройки GitHub/Docker Hub по предыдущему разделу выполните первый push.
Для нового локального Git-репозитория:

```bash
git init -b main
git add .
git status --short
# В индексе не должно быть .env, .secrets/, state и локальных tfvars.
git commit -m 'Add Yandex Cloud diploma project'
git remote add origin https://github.com/SKISHCHENKO/devops-diplom.git
git push -u origin main
```

Если Git уже инициализирован, повторный `git init` не нужен. Если `origin` уже
существует, сначала проверьте `git remote -v`, не добавляйте его повторно.
Для последующих изменений достаточно обычного add/commit/push.

Первый push запускает два workflow одного репозитория:

1. **Terraform CI-CD** проверяет конфигурации. При `TF_APPLY_ENABLED=false`
   job `apply` пропускается; сеть и ВМ не создаются. При значении `true`
   выполняются plan/apply основного стека.
2. **Application CI-CD** собирает Docker-образ из `app/`, проверяет nginx и HTTP,
   публикует `<IMAGE_NAME>:main` и `sha-<полный_commit>`.

Дождитесь успешных проверок и публикации образа. Пропущенный `apply` в режиме
подготовки ожидаем; такой запуск не подтверждает выполнение Terraform CD.
Первый коммит main не требует `KUBE_CONFIG_B64`: CD выполняется по тегу
только при `K8S_DEPLOY_ENABLED=true`.

## Установка Kubernetes

Этот этап создаёт ВМ. Когда будете готовы к развёртыванию, добавьте облачные
секреты по таблице выше, задайте `TF_APPLY_ENABLED=true` и выполните новый
commit/push в main. Дождитесь успешного Terraform pipeline. Изменение только
переменной не запускает workflow. Из корня проекта, с активированным Python venv:

```bash
bash scripts/cluster.sh
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

Скрипт использует тот же S3 state, выполняет Terraform apply, генерирует
inventory из актуальных outputs и запускает Ansible. Если предыдущий workflow
уже создал ВМ, повторного создания неизменённых ресурсов не требуется.

Ansible подготавливает ОС, устанавливает K3s `v1.36.5+k3s1` и ждёт три узла Ready.
Плейбук рассчитан на новую установку или повторный запуск этой minor-ветки;
существующая установка другой ветки останавливает выполнение до изменения
конфигурации. Для её обновления требуется отдельный поэтапный план.
Kubeconfig записывается в `.generated/admin.kubeconfig` и `~/.kube/config`.
Предыдущий `~/.kube/config`, если он существовал, сохраняется рядом как
`config.before-diplom-*`.

После изменения SSH-ключа, `ADMIN_CIDR` или параметров инфраструктуры в `.env` повторите `bootstrap.sh`,
чтобы обновить локальные tfvars, затем `cluster.sh`. Если изменились параметры
основного стека, обновите соответствующий секрет `TFVARS_JSON` в общем репозитории.

Изменение только `IMAGE_NAME`, `IMAGE_TAG` или переключателей Actions не требует bootstrap.

## Мониторинг и первоначальный деплой

Образ `<IMAGE_NAME>:main` уже должен быть опубликован первым workflow приложения.

```bash
bash scripts/deploy.sh
# Дайте Prometheus 2–5 минут для сбора первых метрик.
bash scripts/verify.sh
terraform -chdir=terraform/cluster output app_url
terraform -chdir=terraform/cluster output grafana_url
```

`deploy.sh` устанавливает `kube-prometheus-stack`, создаёт секрет Grafana,
Ingress и дашборд, затем разворачивает приложение из `IMAGE_NAME:IMAGE_TAG`.
`verify.sh` проверяет готовность узлов и компонентов, HTTP приложения/Grafana
и наличие метрики трёх Ready-узлов в Prometheus.

Для Grafana логин — `admin`, пароль хранится в `.secrets/grafana-password`:

```bash
cat .secrets/grafana-password
```

В K3s используются SQLite и встроенные компоненты управления. Отдельные scrape
jobs для etcd, controller-manager, scheduler и kube-proxy отключены. Включены
метрики API, kubelet/cAdvisor, узлов и объектов Kubernetes.

В Grafana откройте «Диплом — Kubernetes»: Ready-узлы, Running-pod, CPU и RAM.
Также доступны встроенные Kubernetes dashboards.

SSH разрешён с `ADMIN_CIDR`. Kubernetes API доступен на 6443 для внешних
GitHub runners с проверкой CA и RBAC. Внутренний обмен разрешён участникам
общей security group; VXLAN не открыт всему Интернету.

При повторном `deploy.sh` снова применяется образ из `IMAGE_NAME:IMAGE_TAG`.
После релиза обновите `IMAGE_TAG` в `.env`, если планируете повторно запускать
этот скрипт, чтобы случайно не вернуть приложение к образу `main`.

## CD по тегу

При первоначальном деплое создаётся ServiceAccount `github-deployer`.
Его kubeconfig находится в `.secrets/ci.kubeconfig`, а base64-версия —
в `.secrets/ci-kubeconfig.b64`. Вставьте содержимое второго файла в секрет
`KUBE_CONFIG_B64` того же GitHub-репозитория.

После этого задайте repository variable `K8S_DEPLOY_ENABLED=true`.
До её включения теги собираются и публикуются, а job `deploy` пропускается.

Этот аккаунт может обновлять только Deployment `diplom-web` в namespace `app`.
Административного доступа к кластеру у CD нет.

Создайте тег в общем репозитории:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Workflow приложения соберёт и протестирует образ, опубликует тег `v1.0.0`
с OCI version label и обновит Deployment по неизменяемому digest.
После успешного rollout `/version.txt` должен возвращать `v1.0.0`.

Для демонстрации следующего обновления измените `app/html/index.html`,
сделайте commit/push и создайте новый тег, например `v1.0.1`.

## Работа обоих workflow

| Событие в общем репозитории | Terraform CI-CD | Application CI-CD |
|---|---|---|
| Коммит main, включая README | проверки; plan/apply при `TF_APPLY_ENABLED=true` | сборка, HTTP-тест и публикация образа |
| Коммит другой ветки | автоматически не запускается | сборка, HTTP-тест и публикация образа |
| Pull request в main | проверки без облачных секретов | CI запускается при push исходной ветки |
| Push тега, например v1.0.0 | не запускается | сборка, тест, публикация; CD по digest при `K8S_DEPLOY_ENABLED=true` |
| Ручной Run workflow | проверки; apply разрешён только на main при включённой переменной | сборка/публикация; CD только для тега при включённой переменной |

У Terraform workflow нет `paths`-фильтра: после включения `TF_APPLY_ENABLED=true`
автоматический apply при любом коммите main соответствует выбранной в задании
альтернативе Atlantis/Terraform Cloud. Для окончательной сдачи обе переменные
должны быть включены и подтверждены реальными запусками; подготовительный
режим с пропущенными apply/deploy не завершает эти пункты задания.
У workflow приложения тоже нет фильтра по каталогу: CI работает при каждом
коммите, хотя Docker build context ограничен `app/`.

Bootstrap и установка Kubernetes выполняются локальными скриптами. Terraform
pipeline управляет сетью и ВМ. После замены ВМ повторите `cluster.sh` и `deploy.sh`;
для неизменённых ВМ повторная установка не нужна.

В выбранном S3 backend нет распределённой блокировки. Terraform workflow
сериализован через `concurrency: terraform-cluster`. Локальные apply/destroy
запускайте после завершения активного workflow, чтобы не изменять один state
из двух процессов одновременно.

GitHub Actions предоставляет веб-интерфейс CI/CD по HTTPS. Отдельная ВМ
Jenkins/TeamCity не используется. Приложение и Grafana обслуживаются по HTTP/80,
как требуется для этих двух интерфейсов в задании.

## Локальная проверка приложения и конфигураций

Сборка и HTTP-тест приложения из корня репозитория:

```bash
docker build --build-arg APP_VERSION=local --build-arg VCS_REF=local -t diplom-web:test ./app
bash app/scripts/test.sh diplom-web:test
```

Тест проверяет `nginx -t`, `/healthz`, HTML, наличие версии и HTTP 404
для отсутствующего файла. Временный контейнер удаляется после проверки.

Проверка исходников:

```bash
source .venv/bin/activate
bash scripts/validate-local.sh
terraform fmt -check -recursive
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
```

Для отдельной проверки основного Terraform без подключения к S3 используйте
чистую копию `terraform/cluster/` с `init -backend=false`, затем `validate`.
В рабочем каталоге после bootstrap его backend уже настроен; не переключайте
его ради проверки. Workflow выполняет проверку на свежем runner.

Скрипты используют общий кэш Terraform providers: `$HOME/.terraform.d/plugin-cache`.
Провайдер скачивается, когда подходящего пакета нет в рабочем каталоге/кэше;
`bootstrap` и основной стек переиспользуют одну копию выбранной версии.
Если пакет был установлен в каталогах этого проекта до включения кэша,
скрипты сначала перенесут его полную копию в кэш; существующие пакеты кэша
не перезаписываются. Проверка контрольных сумм по lock-файлу сохраняется.
Путь можно изменить через `TF_PLUGIN_CACHE_DIR` в `.env` или окружении.
GitHub Actions тоже сохраняет и восстанавливает кэш по lock-файлам и платформе.
Доступ к registry для метаданных может требоваться и при наличии кэша.

Если установка провайдера долго остаётся на `Installing`, можно включить
зеркало Yandex. Файл настройки находится в репозитории; добавьте в `.env`:

```dotenv
TF_CLI_CONFIG_FILE=$PWD/terraform/yandex-mirror.tfrc
TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
```

Скрипты выполняются из корня проекта, поэтому `$PWD` в этой настройке
указывает на репозиторий. Пользовательский `~/.terraformrc` не изменяется.

Новые `.terraform.lock.hcl` сохранены в обоих Terraform-каталогах и фиксируют
версию Yandex provider 0.196.0. Их нужно хранить в Git.
Локальные проверки исходников не подтверждают работу облачного backend,
публикацию Docker image или готовность живого кластера. Эти результаты
проверяются фактическими запусками pipeline и `scripts/verify.sh`.

## Повторное создание и удаление

Чтобы проверить воспроизводимость основного стека:

```bash
bash scripts/destroy.sh
bash scripts/cluster.sh
bash scripts/deploy.sh
bash scripts/verify.sh
```

`destroy.sh` удаляет ВМ, диски, IP и сеть основного стека. Bootstrap и бакет
остаются для следующего apply. При пересоздании управляющего узла старые PVC
мониторинга удаляются вместе с его диском.

После пересоздания кластера замените `KUBE_CONFIG_B64` в этом же репозитории
новым содержимым `.secrets/ci-kubeconfig.b64` и обновите ссылки в отчёте.

Прерываемый worker может быть остановлен провайдером. Найдите его ID:

```bash
terraform -chdir=terraform/cluster output nodes
# Подставьте ID worker и используемый профиль:
yc --profile default compute instance start <ID_worker>
```

K3s agent запускается через systemd и снова подключается к server.

Для окончательной очистки сначала удалите основной стек, затем bootstrap
от пользовательского профиля. Эта последняя команда удаляет бакет со всеми
версиями state и созданные сервисные аккаунты:

```bash
bash scripts/destroy.sh
unset YC_SERVICE_ACCOUNT_KEY_FILE YC_SERVICE_ACCOUNT_KEY
export YC_TOKEN="$(yc --profile default iam create-token)"
terraform -chdir=terraform/bootstrap destroy
unset YC_TOKEN
```

При использовании `yc` замените `default` на `yc`. Для сохранения возможности
нового apply достаточно удалить только основной стек через `destroy.sh`.

## Что предоставить для сдачи

Заполните фактическими результатами таблицу в этом разделе. По заданию
необходимо предоставить исходники Terraform и готовность показать создание
ресурсов с нуля, Ansible-конфигурацию для выбранного способа установки,
Dockerfile и опубликованный образ, конфигурацию Kubernetes, ссылки на
работающие приложение и Grafana с данными доступа. Для выбранного Terraform
CI/CD нужны снимки реально выполненного pipeline.

| Материал | Ссылка / результат |
|---|---|
| Общий GitHub-репозиторий | <https://github.com/SKISHCHENKO/devops-diplom> |
| Terraform | [terraform/](terraform/), отдельно [bootstrap/](terraform/bootstrap/) и [cluster/](terraform/cluster/) |
| Ansible и K3s | [ansible/](ansible/) |
| Kubernetes и мониторинг | [kubernetes/](kubernetes/) |
| Dockerfile приложения | [app/Dockerfile](app/Dockerfile) |
| Docker Hub repository | <https://hub.docker.com/r/skishchenko/devops-diplom-app> |
| Опубликованный релизный image и тег | заполнить после публикации |
| Terraform pipeline от коммита main с init/plan/apply | заполнить ссылку на успешный запуск |
| CI приложения: build/test/push | заполнить ссылку на успешный запуск |
| CD нового релизного тега | заполнить ссылку на успешный rollout |
| Приложение HTTP/80 | заполнить после развёртывания |
| Grafana HTTP/80 | заполнить после развёртывания |
| Логин Grafana | `admin` |
| Пароль Grafana | передать проверяющему отдельно из `.secrets/grafana-password` |
| Проверка Kubernetes | приложить фактический вывод `kubectl get nodes -o wide` и `kubectl get pods --all-namespaces` |
| Воспроизводимость инфраструктуры | быть готовым показать destroy/apply основного стека по разделу выше |

**Скриншоты, прямо запрошенные заданием.** Для выбранной альтернативы
Atlantis/Terraform Cloud нужны снимки Terraform CI/CD pipeline. Число кадров
и имена файлов не установлены. Рекомендуется сохранить общий вид успешного
запуска от `push` в `main` и раскрытый шаг с успешными `init`, `plan`, `apply`
и итогом применения. Если вывод не помещается, добавьте кадры с продолжением
и ссылку на логи. `validate` с пропущенным `apply` подтверждает только подготовку.

**Дополнительные рекомендуемые снимки.** Они помогают подтвердить ожидаемый
результат, но в задании не выделены в отдельный обязательный список:

| Что снять | Что должно быть видно |
|---|---|
| CI приложения | успешные сборка, nginx/HTTP-тест и публикация |
| Docker Hub | имя repository, опубликованные main/release теги и digest |
| Kubernetes | три Ready-узла версии 1.36 и pods без аварийных состояний |
| Grafana | адрес интерфейса и заполненный Kubernetes dashboard с CPU/RAM/узлами |
| Приложение | HTTP-адрес, страница и версия из `/version.txt` |
| CD релизного тега | успешный deploy job, digest и обновлённая версия |

Снимки CI приложения и Docker Hub можно получить до создания ВМ. Остальные
подтверждения снимаются после фактического развёртывания. При необходимости
добавьте Ansible play recap, параметры трёх ВМ, роли Terraform SA и бакет со
state. Пароли, токены и приватные ключи на снимках и в публичном README не показываются.

Перед итоговой демонстрацией включите `TF_APPLY_ENABLED=true` и
`K8S_DEPLOY_ENABLED=true`. Проверьте, что коммит main действительно выполняет
Terraform apply, коммит приложения публикует image, а новый тег выполняет CD.
Изменение только repository variable не запускает workflow: нужен новый
commit/push или ручной запуск, а для подтверждения задания покажите запуск от коммита.
Дашборды должны содержать метрики, а обязательные ссылки на приложение
и Grafana — открываться у проверяющего. Скриншоты дополняют эти ссылки.

Этот README описывает исходники и порядок запуска. Фактическую публикацию,
работу backend и живого кластера подтверждают реальные запуски, логи и ссылки.
