
## 文件说明

- basic-images
  * 该目录下所有脚本，都是用来构建基础镜像的脚本
  * 这些镜像将上传华为云，作为各个项目的基础镜像

- Project开头的文件
  * 脚本模版。具体项目，使用这些模版编写创建镜像和启动容器的脚本

- env开头的文件
  * env-docker.sh 【具体项目使用】存放项目中与容器相关的变量，根据用途不同，可以分成多个 env 开头的文件

- 工具脚本
  * func\_\<xxx\>.sh 具体项目中使用的各种公共函数。例如：func_docker.sh


## 项目部署发布的脚本
- 新项目需要给客户上线部署时，带去客户现场的脚本包括：
  * env-global.sh、env-docker.sh等环境文件。
  * fd\_utils.sh, func\_\<xxx\>.sh
  * 基于 Project-crtcar-Template.sh，为本项目编写的启动容器的脚本

- 以下文件，是公司内部使用的，不需要带去客户现场：
  * basic-images
  * Project开头的脚本模版
