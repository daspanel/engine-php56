
# Usage


### Get
```shell
$ docker pull daspanel/engine-php56:latest
```

### Run
```shell
$ docker run -e DASPANEL_MASTER_EMAIL=my@email.com --name=my-engine-php56 daspanel/engine-php56:latest
```

### Stop
```shell
$ docker stop my-engine-php56
```

### Update image
```shell
$ docker stop my-engine-php56
$ docker pull daspanel/engine-php56:latest
$ docker run -e DASPANEL_MASTER_EMAIL=my@email.com --name=my-engine-php56 daspanel/engine-php56:latest
```

# Tips
