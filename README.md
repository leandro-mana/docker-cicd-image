# Docker CICD Image

The purpose of this repository is to define a `Docker CICD Image` to be used for Local development as well as in continuous integration and continuous delivery (CICD) pipelines

### **Make**

- requirements:
    - `GNU Make 4.3`
    - [docker](https://docs.docker.com/get-docker/)
```bash
# Help message
make [help]

# Build the image
make build

# Clean dangling Images and stopped containers
make clean
```

The proposed pattern is to have as local development environment the same as its on the CICD pipeline, this way is a common ground to standardize versions and tools to replicate similar results as well as to find issues prior to PR processes.

Usually by using a wrapper to mount the repository into the image, to run builds, tests, etc. For an example on how to use this image in such context, check:
- [aws-terraform-example](https://github.com/leandro-mana/aws-terraform-example)
- [aws-terraform-serverless-example](https://github.com/leandro-mana/aws-terraform-serverless-example)

**Contact:** [Leandro Mana](https://www.linkedin.com/in/leandro-mana-2854553b/)
