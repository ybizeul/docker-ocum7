## Introduction

This project is used to build a docker image for NetApp OCUM 7.x, successfully
tested with OCUM 7.1.

More informations about OCUM can be found here :

http://www.netapp.com/us/products/management-software/oncommand/unified-manager.aspx

## Principles

This Dockerfile uses a number of tricks to make OCUM rpm believe they are being
installed on a RHEL 7 system, and make sure all the commands executed during
the installation do not fail.

Especially, it works around :
- Memory check to make the installer believe we have the necessary RAM
- systemctl limitation that prevents it to run in a docker container
- Java parameters that lets OCUM run on a small memory system/container

## Building an image

Obviously, you need a valid entitlement to build this docker image. The RPM
files for OCUM and dependencies are expected in a YUM repository that you
can customize by editing `OCUM.repo`.

If you do not have a YUM repository available, you can use `ybizeul/yum` docker
image to run one in a container, then run `docker inspect` to retrieve container
IP address and configure it into `OCUM.repo`.

Then you can run `docker build .`


