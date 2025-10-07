# terraform-aws-gitops

Deploy EKS and VPC:
```bash
terraform apply
```

Configure EKS cluster:
```bash
aws eks update-kubeconfig --name eks
```

---

### Argo CD

Deploy Argo CD:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Run port-forward for getting to the dashboard https://127.0.0.1:8080:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

ID: `admin` Pass:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

---

### External DNS

Setup helm repo:
```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
```

Install external-dns chart:
```bash
helm upgrade -i external-dns external-dns/external-dns \
  --create-namespace \
  --namespace external-dns \
  --set serviceAccount.name=external-dns-controller \
  --set "domainFilters[0]=aws.shubhamtatvamasi.com" \
  --set txtOwnerId=external-dns
```

---

### Cert Manager

add repo for cert-manager:
```bash
helm repo add jetstack https://charts.jetstack.io
```

install cert-manager:
```bash
helm upgrade -i cert-manager jetstack/cert-manager \
  --create-namespace \
  --namespace cert-manager \
  --set crds.enabled=true
```

Setup ClusterIssuer:
```bash
kubectl apply -f - << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-issuer
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
EOF
```

---

### NGINX Ingress Controller

add repo for ingress-nginx:
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

Install NGINX Ingress Controller:
```bash
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace ingress-nginx \
  --set controller.ingressClassResource.default=true \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=alb
```

---

### actions-runner-controller


Helm add repo for `actions-runner-controller`:
```bash
helm repo add actions-runner-controller \
  https://actions-runner-controller.github.io/actions-runner-controller
```

Helm install `actions-runner-controller`:
```bash
helm install actions-runner-controller \
  actions-runner-controller/actions-runner-controller \
  --set=authSecret.create=true \
  --set=authSecret.github_token="REPLACE_YOUR_TOKEN_HERE" \
  --namespace actions-runner-system \
  --create-namespace
```

Create a `self-hosted-runner`:
```yaml
kubectl apply -f - << EOF
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: self-hosted-runner
  namespace: actions-runner-system
spec:
  replicas: 1
  template:
    spec:
      # repository: ShubhamTatvamasi/python-app-1
      organization: ShubhamBackstage
EOF
```


---

### Nginx setup

Deploy nginx:
```bash
kubectl create deployment nginx --image=nginx:alpine
kubectl expose deployment nginx --port=80 --name=nginx
```

Setup Ingress for nginx with TLS:
```bash
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    external-dns.alpha.kubernetes.io/hostname: aws.shubhamtatvamasi.com
spec:
  tls:
  - hosts:
      - aws.shubhamtatvamasi.com
    secretName: nginx-tls
  rules:
  - host: aws.shubhamtatvamasi.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```
