# AWS EKS Cluster Setup Guide

A comprehensive, step-by-step guide for deploying a production-ready Amazon EKS (Elastic Kubernetes Service) cluster on AWS.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
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

## 📁 Repository Structure

```
aws-eks-cluster-setup/
│
├── README.md                          # Main documentation
├── k8s-manifests/                     # Kubernetes manifests
│   ├── nginx-deployment.yaml          # Sample nginx deployment
│   └── nginx-service.yaml             # LoadBalancer service
│
└── scripts/                           # Installation scripts (optional)
    ├── install-aws.sh                 # AWS CLI installation
    └── install-kubectl.sh             # kubectl installation
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

Now that your cluster is ready, let's deploy a sample nginx application to verify everything works correctly.

#### Step 1: Create Nginx Deployment

**Option A: Use the provided YAML file from this repository**

```bash
# Clone this repository (if you haven't already)
git clone <your-repo-url>
cd aws-eks-cluster-setup

# Apply the deployment
kubectl apply -f k8s-manifests/nginx-deployment.yaml
```

**Option B: Create the YAML file manually**

Create a deployment file:

```bash
nano nginx-deployment.yaml
```

Add the following content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

Deploy the application:

```bash
kubectl apply -f nginx-deployment.yaml
```

#### Step 2: Create LoadBalancer Service

**Option A: Use the provided YAML file from this repository**

```bash
kubectl apply -f k8s-manifests/nginx-service.yaml
```

**Option B: Create the YAML file manually**

Create a service file:

```bash
nano nginx-service.yaml
```

Add the following content:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    app: nginx
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Deploy the service:

```bash
kubectl apply -f nginx-service.yaml
```

⏱️ **Wait Time:** 2-3 minutes for AWS to provision the LoadBalancer (ELB)

#### Step 3: Verify Deployment

Check deployment status:

```bash
# View deployments
kubectl get deployments

# View pods
kubectl get pods

# View services
kubectl get services
```

Expected output for services:
```
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
kubernetes      ClusterIP      10.100.0.1      <none>                                                                   443/TCP        30m
nginx-service   LoadBalancer   10.100.50.123   a1234567890abcdef.us-east-1.elb.amazonaws.com                          80:31234/TCP   2m
```

#### Step 4: Access the Application

Get the LoadBalancer URL:

```bash
kubectl get service nginx-service -o wide
```

Or get just the URL:

```bash
kubectl get service nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Copy the `EXTERNAL-IP` (LoadBalancer DNS name) and paste it in your browser. You should see the nginx welcome page!

#### Step 5: Verify Pod Distribution

Check which nodes the pods are running on:

```bash
kubectl get pods -o wide
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS   AGE   IP            NODE
nginx-deployment-xxxxx-yyyyy        1/1     Running   0          5m    10.0.1.10     ip-10-0-1-100.ec2.internal
nginx-deployment-xxxxx-zzzzz        1/1     Running   0          5m    10.0.2.15     ip-10-0-2-150.ec2.internal
nginx-deployment-xxxxx-aaaaa        1/1     Running   0          5m    10.0.1.20     ip-10-0-1-100.ec2.internal
```

#### Step 6: Test Load Balancing

Test the LoadBalancer with multiple requests:

```bash
# Get the LoadBalancer URL
LB_URL=$(kubectl get service nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Send multiple requests
for i in {1..10}; do
  curl -s http://$LB_URL | grep -i "welcome to nginx"
done
```

#### Alternative: Quick Deployment Commands

If you prefer quick commands without YAML files:

```bash
# Create deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose as LoadBalancer
kubectl expose deployment nginx --port=80 --type=LoadBalancer --name=nginx-service

# Check status
kubectl get all
```

### Scaling the Deployment

Scale your nginx deployment up or down:

```bash
# Scale up to 5 replicas
kubectl scale deployment nginx-deployment --replicas=5

# Scale down to 2 replicas
kubectl scale deployment nginx-deployment --replicas=2

# Check scaling status
kubectl get deployment nginx-deployment
```

### View Application Logs

```bash
# Get pod names
kubectl get pods

# View logs from a specific pod
kubectl logs <pod-name>

# Stream logs
kubectl logs -f <pod-name>

# View logs from all nginx pods
kubectl logs -l app=nginx
```

### Clean Up Sample Application

When done testing, remove the nginx deployment:

```bash
# Delete service (this removes the LoadBalancer)
kubectl delete service nginx-service

# Delete deployment
kubectl delete deployment nginx-deployment

# Or delete using YAML files
kubectl delete -f nginx-service.yaml
kubectl delete -f nginx-deployment.yaml

# Verify deletion
kubectl get all
```

⚠️ **Important:** Always delete the LoadBalancer service to avoid AWS charges for the ELB!

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

### LoadBalancer Stuck in Pending State

```bash
# Check service events
kubectl describe service nginx-service

# Common causes:
# 1. Insufficient permissions - Check IAM roles
# 2. Subnet configuration - Ensure public subnets are tagged correctly
# 3. VPC configuration - Verify internet gateway and route tables

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods

# Describe pod for details
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name>

# Common issues:
# - Image pull errors: Check ECR permissions
# - Resource constraints: Check node capacity
# - Configuration errors: Verify YAML syntax
```

### Cannot Access Application via LoadBalancer

```bash
# Verify LoadBalancer is created
kubectl get svc nginx-service

# Check LoadBalancer in AWS Console
# EC2 → Load Balancers

# Verify target group health
# Check security group rules allow traffic on port 80

# Test from EC2 instance
curl <loadbalancer-dns>

# Check pod endpoints
kubectl get endpoints nginx-service
```

### Permission Issues

Ensure your IAM user/role has the necessary EKS permissions and the aws-auth ConfigMap is properly configured.

---

## 🧹 Cleanup

To avoid AWS charges, delete resources in reverse order:

1. **Delete Sample Application (if still running):**
   ```bash
   kubectl delete service nginx-service
   kubectl delete deployment nginx-deployment
   ```

2. **Delete Node Group:**
   ```bash
   # Via Console: EKS → Cluster → Compute → Delete Node Group
   ```

3. **Delete EKS Cluster:**
   ```bash
   # Via Console: EKS → Delete Cluster
   ```

4. **Terminate EC2 Instance:**
   ```bash
   # Via Console: EC2 → Terminate Instance
   ```

5. **Delete Security Group and VPC** (if no longer needed)

6. **Delete IAM Roles** (if no longer needed):
   - `my-eks-cluster-role`
   - `my-eks-nodegroup-role`
   - `eks-admin-ec2-role`

⚠️ **Critical:** Ensure all LoadBalancer services are deleted before removing the cluster to avoid orphaned AWS ELBs that continue to incur charges!

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
