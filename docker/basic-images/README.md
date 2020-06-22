# 这些都是基础镜像构建脚本

# 编写原则
- 必须设置时区为：TZ=Asia/Shanghai
- 必须包括两个环境变量：HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME
- 必须在最后提供启动容器的样例代码，用于测试该镜像的可用性

# 脚本说明
- 大多数脚本都支持生产和开发的构建方式。
  * 开发模式的镜像：执行脚本时提供命令行参数'-dev'。
  * 生产模式的镜像：体积最小，没有各种无关软件。

- 脚本分类
  * 带有official的脚本，是基于hub.docker.com上的官方镜像
  * 没有official的脚本，是基于原始OS构建的镜像
