Notes:
1. Create two nginx Pods with nodeName and explain how node is polling DB to know what containers to run
2. Delete Pods and comment nodeName line - explain scheduler which is polling DB for Pods without nodeName, decide and writes decision to DB
3. Delete Pods and notice they are gone - no redundancy or recovery etc.
4. Create ReplicaSet with 3 replicas, show effect of changing label
5. Create Service object, client Pod and show balancing works
6. Change Service to by of type LoadBalancer and access service from outside of cluster
7. Delete ReplicaSet and create Deployment, demonstrate upgrade procedure from v1 to v2
8. Show DaemonSet
9. Create namespace, show -n and -A, kubens
10. Create Pod that cats env, set this env directly
11. Set this from Secret
12. Inject Secret as file and explain advantages
13. Create ConfigMap and inject as file
14. Gateway (describe journey from Ingress to Gateway API)
    1.  Install with ```helm install eg oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 -n envoy-gateway-system --create-namespace```
    2.  Deploy web1 and web2 with services and httproute to v1
    3.  Add v2 to backendRefs on 90/10 split
    4.  Remove v2 from split and add as separate rule matching header usertype:beta
    5.  Add hostname - use ```az network dns record-set a add-record -g base -z demo.tkubica.biz -n web -a 1.2.3.4```, configure httproute and show IP only no longer works
    6.  HTTPS - showcase cert-manager and comment on externalDNS and service mesh and argo rollouts or flagger
    ```
    helm repo add jetstack https://charts.jetstack.io
    helm upgrade --install --create-namespace --namespace cert-manager --set installCRDs=true --set featureGates=ExperimentalGatewayAPISupport=true cert-manager jetstack/cert-manager
    ```

15. Lifecycle - kill and see container restart, hang see container not repair -> set lifecycle probe, then demo readiness
16. Init container - create files on volume, read in main container, write in sidecar
17. HPA, requests a cluster autoscaler
18. Affinity
19. PV/PVC - output hostname and date to file and print to logs
20. Security hardening - cluster (RBAC, policies, ...), network policies
21. Security hardening - containers (user, readonly fs, secrets) - show written file, whoami, ping
22. Kustomize
23. Helm
24. ArgoCD and Flux
25. Reference of interesting topics and tooling
    1. Prometheus, Grafana, OpenTelemetry, ...
    2. Workload identity federation
    3. SecretsProviderClass
    4. Application platforms such as DAPR, KNative, OpenFaaS
    5. ML and data analytics with Kubeflow, Vulcano, ...
    6. Service mesh and network security - Cilium, Istio, Linkerd, ...
    7. Operators for running platforms - Kafka, Cassandra, Prometheus, Mongo, ...
    8. DevSecOps - see https://github.com/sottlmarek/DevSecOps
    9. Edge scenarios with k3s
    10. Are more abstracted platforms the next big thing such as Azure Container Apps, Google Cloud Run, AWS Fargate, ...