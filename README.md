## Terraform AWS S3 bucket module

Terraform module that creates S3 bucket and all the required resources with following features:

  * logging
  * object-lifecycle
  * object replication
  * versioning
  * encryption
  * creating dedicated user with R/W access to the bucket

Full featured example is located in example folder. Features are toggled by defining/deleting blocks when using a module. E.g. if you don't want to use versioning in your S3 bucket, don't define it when using this module. Meaning, you only define features that you want to use.