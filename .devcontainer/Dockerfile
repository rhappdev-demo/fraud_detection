FROM quay.io/mhildenb/service-mesh-demo-base:1.0

USER root

# install bc (for bash floating point arithmetic)
RUN yum -y install bc

# install stern
RUN cd /usr/local/bin && \
    wget https://github.com/wercker/stern/releases/download/1.11.0/stern_linux_amd64 && \
    mv stern_linux_amd64 stern && chmod 755 stern

# install AWS cli
RUN curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm awscliv2.zip && rm -rf ./aws 
    # && ln -s /usr/local/bin/aws2 /usr/local/bin/aws

RUN curl -L https://github.com/tektoncd/cli/releases/download/v0.11.0/tkn_0.11.0_Linux_x86_64.tar.gz | \
    tar -xvzf - -C /usr/local/bin/ tkn && chmod 755 /usr/local/bin/tkn

# overwrite existing oc with the absolute newest version of the openshift client
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | \
    tar -xvzf - -C /usr/bin/ oc && chmod 755 /usr/bin/oc

# install jupyter support on top of existing python3 (for phython extension)
RUN pip3 install jupyter

USER jboss