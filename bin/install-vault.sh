# add metrics
kubectl apply -f https://dev.ellisbs.co.uk/files/components.yaml

# create vault namespace, if it doesn't exist
kubectl get ns vault 2> /dev/null
if [ $? -eq 1 ]
then
    kubectl create namespace vault
fi

# create deployment
kubectl apply -f vault.deployment.yml
