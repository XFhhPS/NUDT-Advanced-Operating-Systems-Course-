# 实验四：Kubernetes 容器编排实验

本实验为高级操作系统课程的必做实验，围绕容器技术与 Kubernetes 集群展开，重点掌握容器编排平台的核心原理与实际操作。

## 实验目的

- 理解容器（Container）与虚拟机的区别，掌握 Docker 基本用法
- 部署并操作 Kubernetes（K8s）集群
- 理解 Pod、Deployment、Service 等核心资源对象的概念与作用
- 掌握容器编排的基本方法，体验微服务的调度与管理

## 实验环境

- 操作系统：Linux（推荐 Ubuntu 20.04 及以上）
- 容器运行时：Docker
- 集群工具：Minikube / kubeadm
- 工具：kubectl、YAML 配置文件

## 实验内容

### 1. Docker 基础操作
- 拉取镜像、运行容器
- 构建自定义镜像（Dockerfile）
- 容器网络与存储卷

### 2. Kubernetes 集群部署
- 使用 Minikube 或 kubeadm 搭建单节点/多节点集群
- 节点状态查看（`kubectl get nodes`）
- 集群组件（API Server、Scheduler、Controller Manager、etcd）介绍

### 3. 核心资源对象管理
- **Pod**：最小调度单元，包含一个或多个容器
- **Deployment**：声明式地管理无状态应用的副本数与滚动更新
- **Service**：为 Pod 提供稳定的访问入口（ClusterIP / NodePort / LoadBalancer）
- **ConfigMap / Secret**：配置与敏感信息的管理

### 4. 应用部署案例
- 部署一个简单 Web 服务并通过 Service 对外暴露
- 扩缩容（`kubectl scale`）与滚动更新（`kubectl rollout`）

### 5. 调度与资源管理
- 资源配额（requests / limits）
- 调度策略（nodeSelector、Affinity）

## 文件说明

| 文件 | 说明 |
|------|------|
| `K8s.docx` | 完整实验报告，包含实验步骤、截图与分析 |

## 核心概念

| 概念 | 说明 |
|------|------|
| Pod | K8s 中最小的部署单元，封装一个或多个容器 |
| Deployment | 管理 Pod 副本数量，支持滚动更新和回滚 |
| Service | 为一组 Pod 提供统一的网络访问入口 |
| etcd | 分布式 KV 存储，保存集群所有状态信息 |
| Scheduler | 根据资源和策略将 Pod 分配到合适节点 |

## 参考资料

- [Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/home/)
- [Docker 官方文档](https://docs.docker.com/)
- 课程讲义：容器与编排技术
