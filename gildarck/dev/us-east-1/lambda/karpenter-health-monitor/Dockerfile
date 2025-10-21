FROM public.ecr.aws/lambda/python:3.9

# Install kubectl
RUN yum update -y && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install Python dependencies
RUN pip install boto3 kubernetes PyYAML

# Copy function code
COPY lambda/handler.py ${LAMBDA_TASK_ROOT}

CMD ["handler.lambda_handler"]
