# docker-zoneminder

Docker container for [zoneminder v1.33.3][3]

"ZoneMinder the top Linux video camera security and surveillance solution. ZoneMinder is intended for use in single or multi-camera video security applications, including commercial or home CCTV, theft prevention and child, family member or home monitoring and other domestic care scenarios such as nanny cam installations. It supports capture, analysis, recording, and monitoring of video data coming from one or more video or network cameras attached to a Linux system. ZoneMinder also support web and semi-automatic control of Pan/Tilt/Zoom cameras using a variety of protocols. It is suitable for use as a DIY home video security system and for commercial or professional video security and surveillance. It can also be integrated into a home automation system via X.10 or other protocols. If you're looking for a low cost CCTV system or a more flexible alternative to cheap DVR systems then why not give ZoneMinder a try?"

## Install dependencies

- [Docker][2]

To install docker in Ubuntu 16.04 use the commands:

```bash
sudo apt-get update
sudo wget -qO- <https://get.docker.com/> | sh
```

 To install docker in other operating systems check [docker online documentation][4]

## Usage

To run container use the command below:

```bash
docker run -d --shm-size=4096m -p 80:80 quantumobject/docker-zoneminder:1.33.3
```

**  --shm-size=4096m  ==> work only after docker version 1.10

To run with MySQL in a separate container use the command below:

```bash
docker network create net
docker run -d -e TZ=America/Argentina/Buenos_Aires -e MYSQL_USER=zmuser -e MYSQL_PASSWORD=zmpass -e MYSQL_DATABASE=zm -e MYSQL_ROOT_PASSWORD=mysqlpsswd -e MYSQL_ROOT_HOST=% --net net --name db mysql/mysql-server:5.7
echo "wait until MySQL startup..."
docker run -d -e TZ=America/Argentina/Buenos_Aires -e ZM_DB_HOST=db --net net --name zm -p 80:80 quantumobject/docker-zoneminder:1.33.3
```

## Set the timezone per environment variable

    -e TZ=Europe/London

or in yml:

  environment:

     - TZ=Europe/London

Default value is America/New_York .

## Accessing the Zoneminder applications

After that check with your browser at addresses plus the port assigned by docker:

- <http://host_ip:port/zm/>

Them log in with login/password : admin/admin , Please change password right away and check on-line [documentation][6] to configure zoneminder.

note: ffmpeg was added and path for it is /usr/bin/ffmpeg  if needed for configuration at options .

and if you change System=> "Authenticate user logins to ZoneMinder" you at this moment need to change "Method used to relay authentication information " to "None" if this not done you will be unable to see live view. This only recommended if you are using https to protect password(This relate to a misconfiguration or problem with this container still trying to find a better solutions).

if timeline fail please check TimeZone at php.ini is the correct one for your server( default is America/New York).

To access the container from the server that the container is running :

$ docker exec -it container_id /bin/bash

## Docker Swarm deployment

This projects is implemented to be deployed as docker-compose or swarm stack. Here an example of the docker swarm stack

```yml
version: '3.3'

services:
  db:
    image: mariadb:10.4.12
    networks:
      - net
    volumes:
      - /home/data/zm/mysql:/var/lib/mysql
      # comment on first run to allow MySQL Empty DB Creation
      - $PWD/conf/mysql/my.cnf:/etc/mysql/conf.d/zm.cnf:ro
    environment:
     - TZ=America/Argentina/Buenos_Aires
     - MYSQL_USER=zmuser
     - MYSQL_PASSWORD=zmpass
     - MYSQL_DATABASE=zm
     - MYSQL_ROOT_PASSWORD=mysqlpsswd
     - MYSQL_ROOT_HOST=%
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
       condition: on-failure
       max_attempts: 3
       window: 120s
  web:
    image: quantumobject/docker-zoneminder:1.34
    networks:
      - net
    volumes:
      - /var/empty
      - /home/data/zm/backups:/var/backups
      - /home/data/zm/zoneminder:/var/cache/zoneminder
      - type: tmpfs
        target: /dev/shm
    environment:
     - TZ=America/Argentina/Buenos_Aires
     - VIRTUAL_HOST=zm.localhost, stream0.localhost
     - SERVICE_PORTS="80"
     - ZM_SERVER_HOST=node.0
     - ZM_DB_HOST=db
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
    depends_on:
      - db 
  stream:
    image: quantumobject/docker-zoneminder:1.34
    networks:
      - net
    volumes:
      - /var/empty
      - /home/data/zm/backups:/var/backups
      - /home/data/zm/zoneminder:/var/cache/zoneminder
      - type: tmpfs
        target: /dev/shm
    environment:
     - TZ=America/Argentina/Buenos_Aires
     - VIRTUAL_HOST=stream0.localhost
     - SERVICE_PORTS="80"
     - ZM_SERVER_HOST=node.1
     - ZM_DB_HOST=db
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
    depends_on:
      - web
  lb:
    image: dockercloud/haproxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - target: 80
        published: 80
        protocol: tcp
    networks:
      - net
    environment:
     - TZ=America/Argentina/Buenos_Aires
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
    depends_on:
      - web
networks:
  net:
    driver: overlay
```

above docker-compose.yml stack example asume a directory structure at $PWD as is

```bash
$PWD/mysql      # (MySQL Data, drwxr-xr-x 6   999 999)
$PWD/zoneminder # (directory for images, drwxrwx--- 5 root 33)
$PWD/backup     # (directory for backups, drwxr-xr-x 2 root root)
$PWD/conf       # (configuration files, drwxrwxr-x  7 1000 1000, only conf/mysql/my.cnf is required)
cat conf/mysql/my.cnf
[mysqld]

sql_mode = NO_ENGINE_SUBSTITUTION
max_connections = 500
skip-grant-tables


```

to deploy above stack first initialize your swarm at least with one node for testing

```bash
docker swarm init
docker stack deploy -c docker-compose.yml zm
echo "wait for a few seconds to MySQL start for the first time"
docker service scale zm_web=1
echo "go to ZoneMinder console Options-Servers and declare node.0->stream0.localhost and node.1 ... node.3, finally start"
docker service scale zm_stream=3
docker service ls
```

the docker image used for load balancing is a modified version of dockercloud/haproxy specially targeted for
using {{.Task.Slot}} placeholder in DNS name resolution, see more details at

- <https://github.com/marcelo-ochoa/dockercloud-haproxy.git>

## More Info

About zoneminder [www.zoneminder.com][1]

To help improve this container [quantumobject/docker-zoneminder][5]

For additional info about us and our projects check our site [www.quantumobject.org][7]

[1]:http://www.zoneminder.com/
[2]:https://www.docker.com
[3]:http://www.zoneminder.com/downloads
[4]:http://docs.docker.com
[5]:https://github.com/QuantumObject/docker-zoneminder
[6]:http://www.zoneminder.com/wiki/index.php/Documentation
[7]:https://www.quantumobject.org
