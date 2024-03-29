#
#
# try to infer the correct DOCKER
ifndef DOCKER
DOCKER	:=$(shell if which docker > /dev/null; \
  then echo 'docker'; exit; \
  else \
  printf "***\n" 1>&2; \
  printf "***Error: Couldn't find a docker executable.\n" 1>&2; \
  printf "***\n" 1>&2; exit 1; fi)
endif


V       := @

LOGIN   := login
BUILD   := build
PUSH    := push
PULL    := pull
TAG     := tag
RUN		:= run
RMI		:= rmi
RM		:= rm 

DOCKER_REGISTRY	=docker.io
DOCKER_ORG		=$(shell docker info 2>/dev/null | sed '/Username:/!d;s/.* //')

# the image name
DOCKER_IMAGE	=opencv_test

DOCKER_FULL_NAME=$(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_IMAGE)

ifeq ("$(DOCKER_ORG)","")
$(warning WARNING: No docker user found, please sign in docker hub use docker login.)
endif
#DOCKER_LOGIN	=$(DOCKER) ${LOGIN}
# docker login -u <username> -p <password>
#SIGN_IN			=$(DOCKER_LOGIN) -u $(USER) -p $(PASSWORD)


CUDA	?=OFF  
# make CUDA=ON build
ifeq ("$(CUDA)","ON")
DEFAULT_RUNTIME	=$(shell docker info 2>/dev/null | sed '/Runtime:/!d;s/.* //')
RUNTIMES=$(shell docker info 2>/dev/null | sed -e '/Runtimes:/!d' -e '/nvidia/!d;s/.*/nvidia/')
ifneq ("$(RUNTIMES)","nvidia")
$(warning WARNING:Runtimes is not found nvidia, should set it!)
endif
ifneq ("$(DEFAULT_RUNTIME)","nvidia")
$(warning WARNING:Default runtime is not nvidia, should set it)
endif
#IMAGE_NAME		=nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04
IMAGE_NAME		=nvcr.io/nvidia/pytorch:22.06-py3
IMAGE_TYPE		+=gpu
endif

###########################################################
# the basic image name
IMAGE_NAME		?=ubuntu:18.04

IMAGE_TYPE		?=cpu

PYTHON_VERSION	?=3.8

OPENCV_VERSION	?=4.6.0

define print
	@echo "docker image: \t ${DOCKER_IMAGE}"
	@echo "Python version: \t ${PYTHON_VERSION}"
	@echo "opencv version: \t $(OPENCV_VERSION)"
endef

#####################################################
# base or dev 
BUILD_TYPE	  =base
BUILD_PROGRESS=auto
BUILD_ARGS	  =--build-arg BASE_IMAGE=$(IMAGE_NAME) \
        --build-arg CUDA_SUPPORT=${CUDA} \
		--build-arg OPENCV_VERSION=$(OPENCV_VERSION)
EXTRA_DOCKER_BUILD_FLAGS?=

# build docker image
BUILD_CMD	=DOCKER_BUILDIT=1 \
		 $(DOCKER) $(BUILD) --progress=$(BUILD_PROGRESS) \
		 $(EXTRA_DOCKER_BUILD_FLAGS) \
		 --target $(BUILD_TYPE) \
		 -t $(DOCKER_FULL_NAME):$(TAG_VERSION) \
		 $(BUILD_ARGS) .

# push the docker image
DOCKER_TAG	=latest
PUSH_CMD	=$(DOCKER) $(PUSH) $(DOCKER_FULL_NAME):$(DOCKER_TAG)

# remove the docker image
RM_IMAGE_ID	=$(shell docker images -a -q $(DOCKER_ORG)/$(DOCKER_IMAGE):$(TAG_VERSION))
RMI_CMD_ID		=$(DOCKER) $(RMI) -f $(RM_IMAGE_ID)
RM_IMAGE	=$(shell docker images -a -q -f dangling=true)
RMI_CMD		=$(DOCKER) $(RMI) -f $(RM_IMAGE)

# tag for image 
# 1.0 +
TAG_VERSION =$(IMAGE_TYPE)_1.6
TAG_CMD		=$(DOCKER) $(TAG) $(DOCKER_FULL_NAME):$(TAG_VERSION) $(DOCKER_FULL_NAME):$(DOCKER_TAG)

# create a container use the docker image 
RUN_IMAGE	=$(DOCKER_FULL_NAME):$(DOCKER_TAG)
VOLUME		=/home/l/test/:/test \
			-v /tmp/.X11-unix:/tmp/.X11-unix
ENV			=DISPLAY=$(DISPLAY)

RUN_ARGS	=-it \
		 --name=$(CONTAINER_NAME) \
		 -v $(VOLUME) \
         -e $(ENV)

CONTAINER_NAME	=test_opencv

RUN_CMD		=$(DOCKER) $(RUN) \
		 $(RUN_ARGS) \
		 $(RUN_IMAGE)

#-----------------------------------------------------------------------

COPY	:= cp
MKDIR	:= mkdir -p
MV		:= mv
RM		:= rm -f
AWK		:= sed
SH		:= sh
TOUCH	:= touch -c
PWD		:= pwd

#-----------------------------------------------------------------------
.PHONY:all
all: check 

.PHONY:check
check:
	$(call print)
	@echo "BUILD_CMD:\n $(BUILD_CMD)"
	@echo "TAG_CMD:\n $(TAG_CMD)"
	@echo "RUN_CMD:\n $(RUN_CMD)"
	@echo "PUSH_CMD:\n $(PUSH_CMD)"
	@echo "RMI_CMD:\n -$(RMI_CMD)"
	@echo "RM_CMD_ID:\n -$(RMI_CMD_ID)"
.PHONY:build
build:
	@echo "-----------------strart build image -------------"
	$(V)$(BUILD_CMD)
	$(V)$(TAG_CMD)
	@echo "-------------------------------------------------\n"

.PHONY:push
push:
	@echo "----------------start push ----------------------"
	$(V)$(PUSH_CMD)
	@echo "-------------------------------------------------\n"

.PHONY:run
run:
	@echo "------------------run ----------------------------"
	$(V)$(RUN_CMD)
	@echo "--------------------------------------------------\n"

.PHONY:clean
clean:
	-$(RMI_CMD_ID)
	-$(RMI_CMD)

