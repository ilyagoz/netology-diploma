# Дипломное задание по курсу «DevOps-инженер»

## Краткие результаты

### Инфраструктура

Инфраструктура развернута в [Yandex Cloud](https://cloud.yandex.ru/).

<pre>
$ yc compute instances list --folder-name=netology-diploma
+----------------------+--------+---------------+---------+----------------+---------------+
|          ID          |  NAME  |    ZONE ID    | STATUS  |  EXTERNAL IP   |  INTERNAL IP  |
+----------------------+--------+---------------+---------+----------------+---------------+
| epdrffq5cjqphsd63psd | db01   | ru-central1-b | RUNNING |                | 192.168.31.24 |
| fhm5n551qcj2qqq6ena1 | runner | ru-central1-a | RUNNING |                | 192.168.30.23 |
| fhm88f4tndl4m6tlpmfh | gitlab | ru-central1-a | RUNNING |                | 192.168.30.5  |
| fhmcsjdng4cngsk89cat | jump   | ru-central1-a | RUNNING | 84.201.132.248 | 192.168.30.18 |
| fhmmlv17783mvoag555c | nginx  | ru-central1-a | RUNNING | <b>51.250.71.57</b>   | 192.168.30.19 |
| fhmpginfb0uqkiobvghe | db02   | ru-central1-a | RUNNING |                | 192.168.30.21 |
| fhmq3ckoo3bddl6c3i1r | app    | ru-central1-a | RUNNING |                | 192.168.30.17 |
+----------------------+--------+---------------+---------+----------------+---------------+
</pre>

Доменное имя зарегистрировано.

<pre>
$ dig <b>www.dev.cbg.ru</b>

; <<>> DiG 9.16.33-RH <<>> www.dev.cbg.ru
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 21284
;; flags: qr rd ad; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 0
;; WARNING: recursion requested but not available

;; QUESTION SECTION:
;www.dev.cbg.ru.                        IN      A

;; ANSWER SECTION:
www.dev.cbg.ru.         0       IN      A       <b>51.250.71.57</b>
ns1.yandexcloud.net.    0       IN      A       84.201.185.208
ns2.yandexcloud.net.    0       IN      A       84.201.189.229

;; Query time: 0 msec
;; SERVER: 192.168.240.1#53(192.168.240.1)
;; WHEN: Wed Sep 28 19:15:07 +07 2022
;; MSG SIZE  rcvd: 132
</pre>

В сети используется статическая маршрутизация и [NAT-шлюз](https://cloud.yandex.ru/docs/vpc/operations/create-nat-gateway):

```
$ yc vpc route-table show nat-route --folder-name=netology-diploma
id: enphd5u984hg4v2hh4c4
folder_id: b1g8ok924udnrjpvt6e2
created_at: "2022-09-24T04:47:42Z"
name: nat-route
network_id: enpepr16v8rll7m8gels
static_routes:

- destination_prefix: 0.0.0.0/0
    gateway_id: enpkq192r8r9et9k51bc
```

Инфраструктура описана и полностью управляется с помощью [Terraform](https://www.terraform.io).

```
$ terraform workspace list
  default
  prod
* stage

$ terraform plan
yandex_vpc_gateway.nat-gateway: Refreshing state... [id=enpkq192r8r9et9k51bc]
yandex_vpc_network.network1: Refreshing state... [id=enpepr16v8rll7m8gels]
yandex_vpc_address.app_ip_address: Refreshing state... [id=e9bh6kg1k2rn5jje1v9a]
yandex_vpc_route_table.nat-route: Refreshing state... [id=enphd5u984hg4v2hh4c4]
yandex_dns_zone.dev-cbg-ru: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp]
yandex_vpc_subnet.subnet-a: Refreshing state... [id=e9beju2evgcfm94c0t5f]
yandex_vpc_subnet.subnet-b: Refreshing state... [id=e2lsegm02fp1afg9a0ho]
yandex_compute_instance.db01: Refreshing state... [id=epdrffq5cjqphsd63psd]
yandex_dns_recordset.rs["prometheus"]: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp/prometheus.dev.cbg.ru./A]
yandex_dns_recordset.rs["runner"]: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp/runner.dev.cbg.ru./A]
yandex_compute_instance.gitlab: Refreshing state... [id=fhm88f4tndl4m6tlpmfh]
yandex_dns_recordset.rs["grafana"]: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp/grafana.dev.cbg.ru./A]
yandex_compute_instance.nginx: Refreshing state... [id=fhmmlv17783mvoag555c]
yandex_compute_instance.jump: Refreshing state... [id=fhmcsjdng4cngsk89cat]
yandex_compute_instance.app: Refreshing state... [id=fhmq3ckoo3bddl6c3i1r]
yandex_compute_instance.runner: Refreshing state... [id=fhm5n551qcj2qqq6ena1]
yandex_compute_instance.db02: Refreshing state... [id=fhmpginfb0uqkiobvghe]
yandex_dns_recordset.rs["www"]: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp/www.dev.cbg.ru./A]
yandex_dns_recordset.rs["alertmanager"]: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp/alertmanager.dev.cbg.ru./A]
yandex_dns_recordset.rs["app"]: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp/app.dev.cbg.ru./A]
yandex_dns_recordset.rs["gitlab"]: Refreshing state... [id=dnsbrdpvakk6ssgmdnmp/gitlab.dev.cbg.ru./A]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes
are needed.
```

Бекэндом Terraform служит бакет в Yandex Cloud:

```terra
backend "s3" {
  endpoint = "storage.yandexcloud.net"
  bucket   = "tf-backend"
  region   = "ru-central1"
  key      = "terraform.tfstate"

  shared_credentials_file = "~/.aws/credentials"
  profile                 = "netology-diploma"

  skip_region_validation      = true
  skip_credentials_validation = true
}
```

Конфигурирование машин полностью выполняется с помощью [Ansible](https://www.ansible.com).

```
$ ansible-playbook  testrole.yml --check -i ./inventory/inventory.ini --ask-vault-pass

[...пропущен ряд строк...]

PLAY RECAP **********************************************************************************************************
app.ru-central1.internal   : ok=18   changed=4    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
db01                       : ok=16   changed=0    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
db02                       : ok=14   changed=0    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
gitlab.ru-central1.internal : ok=3    changed=1    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0

nginx.ru-central1.internal : ok=13   changed=3    unreachable=0    failed=0    skipped=5    rescued=0    ignored=0
runner.ru-central1.internal : ok=5    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

Обратный прокси на базе [NGINX](https://www.nginx.com) с сертификатом [Let's Encrypt](https://letsencrypt.org) работает, доступ к сайтам во внутренней сети через него работает.

[GitLab](https://about.gitlab.com/install) установлен и работает:

![Gitlab secured](images/2022-09-28%2014-58-47.png)

[WordPress](https://wordpress.org) установлен и работает:

![Wordpress secured](images/2022-09-28%2015-03-33.png)

Репликация базы данных MySQL работает:

```
mysql> show slave status\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: db01.ru-central1.internal
                  Master_User: repl_user
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: binlog.000007
          Read_Master_Log_Pos: 197
               Relay_Log_File: db02-relay-bin.000002
                Relay_Log_Pos: 367
        Relay_Master_Log_File: binlog.000007
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
```

Мастер-сервер (`db01`) и реплика (`db02`) расположены в подсетях `subnet-b` и `subnet-a`, находящихся в зонах доступности `ru-central1-b` и  `ru-central1-a`, соответственно.

```
$ yc vpc subnet list --folder-name=netology-diploma
+----------------------+----------+----------------------+----------------------+---------------+-------------------+
|          ID          |   NAME   |      NETWORK ID      |    ROUTE TABLE ID    |     ZONE      |       RANGE       |
+----------------------+----------+----------------------+----------------------+---------------+-------------------+
| e2lsegm02fp1afg9a0ho | subnet-b | enpepr16v8rll7m8gels | enphd5u984hg4v2hh4c4 | ru-central1-b | [192.168.31.0/24] |
| e9beju2evgcfm94c0t5f | subnet-a | enpepr16v8rll7m8gels | enphd5u984hg4v2hh4c4 | ru-central1-a | [192.168.30.0/24] |
+----------------------+----------+----------------------+----------------------+---------------+-------------------+
```

### CI/CD

К сожалению, в рамках настоящей работы не предусмотрена интеграция описания инфраструктуры, полученной в предыдущем разделе, со средствами CI/CD. Исходный код

Для развертывания приложения у нас используется Ansible, и поэтому для GitLab сделан специальный runner с установленным на нем Ansible.

## Пояснения

### Как развернуть инфраструктуру

Установить имя пользователя, от которого Ansible будет соединяться по `ssh`, а также имя jump-сервера в файле `inventory.ini` в строке `ansible_ssh_common_args= '-o "User=<имя пользователя>" -o "ProxyJump=<имя jump-сервера>" -o "StrictHostKeyChecking=no"'`.

Не забудьте установить переменную окружения YC_TOKEN

**ВНИМАНИЕ**: По абсолютно непонятной причине *иногда* подсеть с готовым route_table_id не создается. Поэтому мы вынуждены воспользоваться CLI и `provisioner "local-exec"`. Это лишает нас возможности вносить изменения без полного пересоздания инфраструктуры, так как терраформ заметит появление `route_table_id` и удалит ее, а провизионера повторно не запустит, ибо при update in-place они не запускаются. Соответствующие заклинания:

```shell
yc vpc route-table list  --folder-id=b1g8ok924udnrjpvt6e2 --format yaml
```

```yaml
- id: enphd5u984hg4v2hh4c4
  folder_id: b1g8ok924udnrjpvt6e2
  created_at: "2022-09-24T04:47:42Z"
  name: nat-route
  network_id: enpepr16v8rll7m8gels
  static_routes:
    - destination_prefix: 0.0.0.0/0
      gateway_id: enpkq192r8r9et9k51bc
```

```shell
yc vpc subnet update subnet-a --route-table-id enphd5u984hg4v2hh4c4 --folder-id b1g8ok924udnrjpvt6e2
yc vpc subnet update subnet-b --route-table-id enphd5u984hg4v2hh4c4 --folder-id b1g8ok924udnrjpvt6e2
```

## Настройка SSH для доступа Ansible

Для связи с машинами кластера используется [инсталляционный сервер (или jump-сервер)](https://ru.wikipedia.org/wiki/%D0%98%D0%BD%D1%81%D1%82%D0%B0%D0%BB%D0%BB%D1%8F%D1%86%D0%B8%D0%BE%D0%BD%D0%BD%D1%8B%D0%B9_%D1%81%D0%B5%D1%80%D0%B2%D0%B5%D1%80) — отдельная виртуальная машина, имеющая как внешний, так и внутренний IP-адрес.

Образец настройки jump-сервера: «[Как настроить SSH-Jump Server](https://habr.com/ru/company/cloud4y/blog/530516/)».

Образец настройки Ansible: «[Using an Ansible playbook with an SSH bastion / jump host](https://www.jeffgeerling.com/blog/2022/using-ansible-playbook-ssh-bastion-jump-host)».

В `~/.ssh/config` записывается адрес jump-сервера (выводится после создания инфраструктуры в виде jump_host_ip = "<ip-адрес>"):

``` ssh-config
Host jump
  HostName <ip-адрес>
  User <имя>
  StrictHostKeyChecking no
```

`StrictHostKeyChecking no` для того, чтобы не сталкиваться с предупреждениями SSH после пересоздания инфраструктуры. (В случае чего нужно удалить ключ для данного хоста: `ssh-keygen -R db02`) (Да, это немного снижает безопасность).

Ведение инвентаря в Ansible просто, так как отпадает необходимость знания динамических IP-адресов. С инсталляционного сервера в YC все машины доступны по именам хостов (в домене `.ru-central1.internal`), и для Ansible инвентарь выглядит предельно просто:

```ini
[admin]
jump

[app]
nginx

[db]
db01.ru-central1.internal
db02.ru-central1.internal

[all:vars]
ansible_ssh_common_args= '-o "User=<имя>" -o "ProxyJump=jump" -o "StrictHostKeyChecking=no"'
```

При создании машин на них устанавливаются ключи для администратора  `<имя>` через параметр в описании для Terraform:

``` terra
metadata = {
    user-data = "${file("cloud-config.yml")}"
}
```

`cloud-config.yml`:

```yaml
users:
  - name: <имя>
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - <публичный ключ ssh-rsa...>
```

Добавьте приватный ключ к `ssh-agent` с помощью `ssh-add <путь к файлу приватного ключа>`. После этого доступ к машине, например, `db01` получить можно командой `ssh <имя>@db02 -J jump`. (Ключ `-J` в OpenSSH реализован с версии 7.5). Ansible работает как обычно:

```yaml
- name: Check SSH connections to targets.
  hosts: all
  tasks:
  - action: ping
```

## Установка и настройка MySQL

Официальный способ установки MySQL: [Installing MySQL on Linux Using Debian Packages from Oracle](https://dev.mysql.com/doc/refman/5.7/en/linux-installation-debian.html).

Хороший способ заключается, конечно, в организации локального репозитория нужных пакетов, но это выходит за рамки настоящей работы. Мы установим MySQL в соответствии с [официальным способом из репозитория](https://dev.mysql.com/doc/mysql-apt-repo-quick-guide/en/).

При установке пакет задает вопросы. Список ответов, которые можно заранее установить с помощью модуля `ansible.builtin.debconf`, приведен в [Installing MySQL Non-interactively with MySQL APT Repository](https://dev.mysql.com/doc/mysql-apt-repo-quick-guide/en/#repo-qg-apt-repo-non-insteractive).

Для подключения репозитория необходим его публичный ключ. Файл с ключом называется `mysql_pubkey.asc` и лежит в `files`.

Установка производится с помощью Ansible, роль `mysql_common`. Этот этап одинаков для всех серверов БД в нашей группе.

## Настройка репликации

Репликация настраивается через Ansible с помощью коллекции [`community.mysql`](https://docs.ansible.com/ansible/latest/collections/community/mysql/index.html), в соответствии с инструкциями в документации, глава [Replication](https://dev.mysql.com/doc/mysql-replication-excerpt/5.6/en/replication.html). Используется метод репликации с [GTID](https://dev.mysql.com/doc/refman/8.0/en/replication-gtids.html), как более современный, прогрессивный и простой в настройке.

Конфигурации главного сервера и репликатора отличаются, поэтому они разнесены в разные роли: `mysql_source` и `mysql_replica`, соответственно. В роли `mysql_source` задается необходимый идентификатор `server_id`, создается на ведущем сервере пользователь `repl_user`, от имени которого будет считывать данные репликатор, и, наконец, создается база данных для будущего приложения. В конфигурациях `/etc/mysql/mysql.conf.d/mysqld.cnf`, помимо необходимых настроек для использования GTID, указано через `binlog_do_db=`, что реплицировать нужно только эту базу.

В роли `mysql_replica` база данных не создается, так как она будет создана при начале реплицирования. Для репликатора указывается необходимый идентификатор `server_id`, а затем выдается серия команд `stopreplica`, `changeprimary`, `startreplica`, `getreplica` (последнее только для информации) с одинаковыми параметрами, в том числе `primary_auto_position: true`, указывающим на использование GTID. В результате получаем:

Репликация работает, что показывают параметры `Slave_IO_Running: Yes` и `Slave_SQL_Running: Yes`. Следует отметить, что репликация в MySQL крайне хрупкая и останавливается от любой ошибки в SQL-запросе, после чего ее нужно перезапускать вручную. Учитывая, что наше приложение находится в разработке, и ошибки работы с БД вероятны, рассчитывать на репликацию как на механизм обеспечения отказоустойчивости не стоит. Кроме того, репликация, предусмотренная заданием, работает только в одну сторону, и говорить об автоматическом восстановлении после сбоя не приходится. Репликация, однако, может использоваться для резервного копирования и балансировки нагрузки. Для организации настоящего отказоустойчивого кластера понадобится более сложное решение, например, на основе [InnoDB Cluster](https://dev.mysql.com/doc/mysql-shell/8.0/en/mysql-innodb-cluster.html).

## Установка Gitlab CE и Gitlab Runner

Использование средств работы с секретами в CI [поддерживается только в версии Gitlab Premium](https://docs.gitlab.com/ee/ci/secrets/#use-vault-secrets-in-a-ci-job).

## Установка и настройка NGINX и FastCGI

FastCGI и PHP устанавливаются на машине `app`, NGINX - на машине `nginx`.

<https://nixway.org/2013/06/11/fastcgi_php_fpm_for_nginx/>

Для работы с репозиторием, созданным в нашей установке GitLab, необходимо зарегистрироваться (я сделал это в качестве пользователя 'root') и загрузить свой публичный ключ. Для удобства в `~/.ssh/config` можно внести следующее:

```
Host jump
  HostName <ip-адрес jump-сервера>
  User ivg
  IdentityFile <путь к файлу приватного ключа>

Host gitlab.ru-central1.internal
  HostName gitlab.ru-central1.internal
  ProxyJump jump
```

<http://gitlab.ru-central1.internal>

После этого работа с репозиторием проводится как обычно:

```
$ git clone git@gitlab.ru-central1.internal:wpdev/wordpress.git
Cloning into 'wordpress'...
remote: Enumerating objects: 3104, done.
remote: Counting objects: 100% (3/3), done.
remote: Compressing objects: 100% (3/3), done.
remote: Total 3104 (delta 0), reused 0 (delta 0), pack-reused 3101
Receiving objects: 100% (3104/3104), 19.44 MiB | 1.43 MiB/s, done.
Resolving deltas: 100% (514/514), done.
Updating files: 100% (2891/2891), done.

$ cd wordpress/

$ git status
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

Нет также никаких препятствий к тому, чтобы совместить функции веб-сервера и jump-сервера для экономии ip-адресов.

**Интересный факт про NGINX.** Если ip-адрес сервера, указанного в качестве upstream, сменится во время работы NGINX (например, потому что виртуальная машина была пересоздана, и ей выделяется динамический адрес, несмотря на сохранение доменного имени), то NGINX будет обращаться по старому адресу, отчего все испортится. Способ борьбы с этим существует: [Using DNS for Service Discovery with NGINX and NGINX Plus](https://www.nginx.com/blog/dns-service-discovery-nginx-plus/).

Настройка связи между NGINX на входе и внутренним на приложении производится так, как подробно описано здесь: [HTTPS behind your reverse proxy](https://reinout.vanrees.org/weblog/2017/05/02/https-behind-proxy.html). При этом на приложении используется самоподписанный сертификат, а NGINX перезашифровывает данные и отдает уже с сертификатом Let's encrypt. Разумеется, правильным enterprise-способом была бы установка во внутренней сети собственного удостоверяющего  центра, например, на основе Hashicorp Vault и централизованная раздача сертификатов через него. Но это выходит за рамки настоящей работы. Тем не менее, решение с самоподписанным сертификатом лучше, чем вообще без сертификата - при этом обеспечивается хотя бы шифрование внутреннего трафика, а приложения работают в условиях нормального https.
