# AWS EKS Cluster Setup Guide

A comprehensive, step-by-step guide for deploying a production-ready Amazon EKS (Elastic Kubernetes Service) cluster on AWS.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Setup Instructions](#setup-instructions)
  - [Phase 1: IAM Role Configuration](#phase-1-iam-role-configuration)
  - [Phase 2: Network Setup](#phase-2-network-setup-vpc--sg)
  - [Phase 3: Create EKS Cluster](#phase-3-create-the-eks-cluster-control-plane)
  - [Phase 4: Management Server Setup](#phase-4-create-the-management-server-ec2)
  - [Phase 5: Install Required Tools](#phase-5-install-tools-on-ec2)
  - [Phase 6: Create Node Group](#phase-6-create-node-group-worker-nodes)
  - [Phase 7: Connect and Verify](#phase-7-connect-and-verify)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This guide walks you through creating a fully functional AWS EKS cluster from scratch, including:

- IAM roles and policies configuration
- VPC and networking setup
- EKS control plane deployment
- Worker node provisioning
- Management server configuration
- kubectl integration

**Estimated Setup Time:** 30-45 minutes

## ✅ Prerequisites

Before starting, ensure you have:

- An AWS account with appropriate permissions
- Basic understanding of Kubernetes concepts
- SSH client (Git Bash, Terminal, or PuTTY)
- An existing EC2 key pair (or ability to create one)

### AWS Permissions Required

Your IAM user needs permissions to create:
- IAM Roles and Policies
- VPC and Security Groups
- EKS Clusters
- EC2 Instances
- Node Groups

## 🏗️ Architecture

The setup creates the following infrastructure:

```
┌─────────────────────────────────────────────────────────┐
│                         VPC                              │
│  ┌────────────────┐        ┌─────────────────────────┐  │
│  │ Public Subnet  │        │   EKS Control Plane     │  │
│  │                │        │  (Managed by AWS)       │  │
│  │ ┌────────────┐ │        └─────────────────────────┘  │
│  │ │ EC2 Admin  │ │                    │                │
│  │ │  Server    │ │                    │                │
│  │ └────────────┘ │         ┌──────────┴─────────┐      │
│  └────────────────┘         │                    │      │
│         │              ┌────▼─────┐        ┌─────▼───┐  │
│         │              │  Worker  │        │ Worker  │  │
│         │              │  Node 1  │        │ Node 2  │  │
│         │              └──────────┘        └─────────┘  │
└─────────┴──────────────────────────────────────────────┘
```

## 🚀 Setup Instructions

### Phase 1: IAM Role Configuration

Before creating any resources, we must create IAM Roles for different components:

#### 1.1 Create EKS Cluster Role

1. Navigate to **IAM Console** → **Roles** → **Create Role**
2. **Trusted Entity:** AWS Service → **EKS** → **EKS - Cluster**
3. **Permissions:** Ensure `AmazonEKSClusterPolicy` is attached
4. **Role Name:** `my-eks-cluster-role`
5. Click **Create Role**

#### 1.2 Create Node Group Role

1. Navigate to **IAM Console** → **Roles** → **Create Role**
2. **Trusted Entity:** AWS Service → **EC2**
3. **Permissions:** Attach the following 3 policies:
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEC2ContainerRegistryReadOnly`
   - `AmazonEKS_CNI_Policy`
4. **Role Name:** `my-eks-nodegroup-role`
5. Click **Create Role**

📝 **Note:** The EC2 management server role will be created in Phase 4.

---

### Phase 2: Network Setup (VPC & SG)

#### 2.1 Create VPC

1. Navigate to **VPC Console** → **Create VPC**
2. Select **VPC and more**
3. Configure auto-generated subnets (ensure Public Subnets are included)
4. Click **Create VPC**

#### 2.2 Create Security Group

1. Navigate to **VPC Console** → **Security Groups** → **Create Security Group**
2. **Name:** `eks-cluster-sg`
3. **VPC:** Select the VPC created above
4. **Inbound Rules:**
   - Type: All Traffic
   - Source: `0.0.0.0/0` (IPv4 Anywhere)
   
   ⚠️ **Note:** This is for learning purposes only. In production, restrict access to specific IPs.

5. Click **Create Security Group**

---

### Phase 3: Create the EKS Cluster (Control Plane)

1. Navigate to **EKS Console** → **Add Cluster** → **Create**
2. **Configuration:**
   - **Name:** `my-demo-cluster`
   - **Cluster Service Role:** `my-eks-cluster-role`
3. **Networking:**
   - **VPC:** Select your VPC
   - **Subnets:** Select public subnets
   - **Security Group:** `eks-cluster-sg`
4. **Cluster Access:** Public
5. Click **Next** through logging options → **Create**

⏱️ **Wait Time:** Approximately 10 minutes for cluster to become **Active**

---

### Phase 4: Create the Management Server (EC2)

While the cluster is being created, set up your management server:

#### 4.1 Create IAM Role for EC2 (SSM Access)

1. Navigate to **IAM Console** → **Roles** → **Create Role**
2. **Trusted Entity:** AWS Service → **EC2**
3. **Permissions:** Attach the following policies:
   - `AmazonSSMManagedInstanceCore` (for Systems Manager access)
   - `AdministratorAccess` (for EKS cluster management)
4. **Role Name:** `eks-admin-ec2-role`
5. Click **Create Role**

💡 **Note:** The `AmazonSSMManagedInstanceCore` policy allows you to connect to the instance via AWS Systems Manager (SSM) Session Manager without needing SSH keys.

#### 4.2 Launch EC2 Instance

1. Navigate to **EC2 Console** → **Launch Instance**
2. **Configuration:**
   - **Name:** `eks-admin-server`
   - **OS:** Amazon Linux 2023
   - **Instance Type:** t2.micro
   - **Key Pair:** Select existing or create new (optional if using SSM)
3. **Network Settings:**
   - **VPC:** Same VPC as EKS Cluster
   - **Security Group:** `eks-cluster-sg`
   - **Auto-assign Public IP:** Enable
4. **Advanced Details:**
   - **IAM Instance Profile:** Select `eks-admin-ec2-role`
5. Click **Launch Instance**

⏱️ **Wait Time:** 2-3 minutes for instance to initialize

#### 4.3 Connect to Instance

You can connect using either SSH or AWS Systems Manager:

**Option 1: Connect via SSM (Recommended - No SSH Keys Required)**

1. Navigate to **EC2 Console** → Select `eks-admin-server`
2. Click **Connect** → **Session Manager** → **Connect**

**Option 2: Connect via SSH**

```bash
ssh -i "your-key.pem" ec2-user@<public-ip>
```

✅ **Benefits of SSM:**
- No need to manage SSH keys
- No need to open port 22 in security groups
- Session logging and audit trail
- Works even without public IP (via VPC endpoints)

---

### Phase 5: Install Tools on EC2

#### 5.1 Install AWS CLI

Create installation script:

```bash
nano install-aws.sh
```

Add the following content:

```bash
#!/bin/bash
echo "Installing AWS CLI..."
sudo yum install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip aws
aws --version
```

Execute the script:

```bash
bash install-aws.sh
```

#### 5.2 Install kubectl

Create installation script:

```bash
nano install-kubectl.sh
```

Add the following content:

```bash
#!/bin/bash
echo "Installing Kubectl..."
# Download the latest stable release
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make executable
chmod +x ./kubectl

# Move to bin folder
sudo mv ./kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

Execute the script:

```bash
sudo chmod 777 install-kubectl.sh
./install-kubectl.sh
```

#### 5.3 Verify AWS Configuration

The EC2 instance uses the attached IAM role (`eks-admin-ec2-role`) for AWS authentication, so no manual credential configuration is needed.

Verify your AWS identity:

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/eks-admin-ec2-role/..."
}
```

Set your default region (if needed):

```bash
aws configure set region ap-south-1
```

---

### Phase 6: Create Node Group (Worker Nodes)

Once the EKS Cluster status is **Active**:

1. Navigate to **EKS Console** → Select `my-demo-cluster`
2. Click **Compute** tab → **Add Node Group**
3. **Configuration:**
   - **Name:** `my-workers`
   - **Node IAM Role:** `my-eks-nodegroup-role`
   - **AMI Type:** Amazon Linux 2 (AL2_x86_64)
   - **Instance Type:** `t3.medium` (recommended) or `t2.medium`
4. **Scaling:**
   - **Desired:** 2
   - **Minimum:** 2
   - **Maximum:** 3
5. Click **Next** → **Create**

---

### Phase 7: Connect and Verify

#### 7.1 Update Kubeconfig

Connect kubectl to your cluster:

```bash
aws eks --region ap-south-1 update-kubeconfig --name my-demo-cluster
```

#### 7.2 Verify Nodes

Check worker node status:

```bash
kubectl get nodes
```

⏱️ **Note:** Nodes may take 3-5 minutes to show **Ready** status.

#### 7.3 Detailed Node Information

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME                                           STATUS   ROLES    AGE   VERSION
ip-xxx-xxx-xxx-xxx.ap-south-1.compute.internal Ready    <none>   5m    v1.xx.x
ip-xxx-xxx-xxx-xxx.ap-south-1.compute.internal Ready    <none>   5m    v1.xx.x
```

---

## 🎉 Post-Installation

### Deploy a Sample Application

Test your cluster with a simple nginx deployment:

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get services
```

### Verify Deployment

```bash
kubectl get pods
kubectl get deployments
kubectl get services
```

---

## 🔧 Troubleshooting

### Nodes Not Showing as Ready

```bash
# Check node status
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system
```

### Cannot Connect to Cluster

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update kubeconfig
aws eks --region <region> update-kubeconfig --name <cluster-name>
```

### Permission Issues

Ensure your IAM user/role has the necessary EKS permissions and the aws-auth ConfigMap is properly configured.

---

## 🧹 Cleanup

To avoid AWS charges, delete resources in reverse order:

1. **Delete Node Group:**
   ```bash
   # Via Console: EKS → Cluster → Compute → Delete Node Group
   ```

2. **Delete EKS Cluster:**
   ```bash
   # Via Console: EKS → Delete Cluster
   ```

3. **Terminate EC2 Instance:**
   ```bash
   # Via Console: EC2 → Terminate Instance
   ```

4. **Delete Security Group and VPC** (if no longer needed)

5. **Delete IAM Roles** (if no longer needed):
   - `my-eks-cluster-role`
   - `my-eks-nodegroup-role`
   - `eks-admin-ec2-role`

---

## 🔐 Security Considerations

### Production Best Practices

- **Security Groups:** Restrict inbound rules to specific IP ranges
- **IAM Roles:** Use least privilege principle
- **Private Clusters:** Consider private endpoint access for production
- **Secrets Management:** Use AWS Secrets Manager or Kubernetes Secrets
- **Network Policies:** Implement pod-level network segmentation
- **Logging:** Enable control plane logging
- **Encryption:** Enable encryption at rest for EKS secrets

### Recommended Changes for Production

1. Use private subnets for worker nodes
2. Implement bastion host for SSH access
3. Enable VPC flow logs
4. Use AWS KMS for secret encryption
5. Implement Pod Security Standards
6. Set up monitoring with CloudWatch/Prometheus

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [eksctl - Official CLI for EKS](https://eksctl.io/)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)

---

## 💡 Tips

- Always use version control for your Kubernetes manifests
- Implement Infrastructure as Code (Terraform/CloudFormation) for reproducible environments
- Set up CI/CD pipelines for automated deployments
- Regularly update your cluster and worker node AMIs
- Monitor costs using AWS Cost Explorer

---

**Made with ❤️ for the Kubernetes community**

For questions or issues, please open an issue in this repository.
