terraform {
  backend "s3" {
    bucket = "athene-ci"
    key    = "terraform/authorizers.tfstate"
    region = "us-east-1"
  }
}

variable "AWS_ACCESS_KEY_ID" {}
variable "AWS_SECRET_ACCESS_KEY" {}

provider "aws" {
  version	= "~> 2.10.0"
  region     = "us-east-1"
  access_key = "${var.AWS_ACCESS_KEY_ID}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
}

variable "REGION"  {}
variable "API_ID"  {}
variable "ROOT_RESOURCE_ID" {}
variable "CUSTOMER_USER_POOL_ID" {}
variable "PRODUCER_USER_POOL_ID" {}
variable "ASSOCIATE_USER_POOL_ID" {}


variable "subnet_id_primary" {
  type = "map"

  default = {
    dev   = "subnet-b758e0fc"
    qa    = "subnet-1c8e1078"
    stage = "subnet-7071585c"
    prod  = "subnet-53150637"
  }
}

variable "subnet_id_secondary" {
  type = "map"

  default = {
    dev   = "subnet-85f20caa"
    qa    = "subnet-7a519255"
    stage = "subnet-eaaf41a1"
    prod  = "subnet-e8271bc7"
  }
}

variable "security_group" {
  type = "map"

  default = {
    dev   = "sg-9c2cdde9"
    qa    = "sg-bdac5dc8"
    stage = "sg-e412e391"
    prod  = "sg-d398d998"
  }
}

data "aws_iam_role" "role" {
  name = "Services-Portal"
}

resource "aws_api_gateway_resource" "lambda-authorizer" {
  rest_api_id = "${var.API_ID}"
  parent_id   = "${var.ROOT_RESOURCE_ID}"
  path_part   = "lambda-authorizer"
}

resource "aws_lambda_function" "lambda-authorizer" {
  filename         = "lambda-authorizer.zip"
  function_name    = "lambda-authorizer"
  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/lambda-authorizer.handler"
  source_code_hash = "${base64sha256(file("lambda-authorizer.zip"))}"
  runtime          = "nodejs8.10"
  timeout          = 28

  vpc_config {
    subnet_ids = [
      "${var.subnet_id_primary[var.REGION]}",
      "${var.subnet_id_secondary[var.REGION]}",
    ]

    security_group_ids = [
      "${var.security_group[var.REGION]}",
    ]
  }

  tags {
    CostCenter = 67606
    System     = "Portal"
    Region     = "${var.REGION}"
  }

  environment {
    variables = {
      CONSUMER_POOL_ID   = "${var.CUSTOMER_USER_POOL_ID}"
      PRODUCER_POOL_ID   = "${var.PRODUCER_USER_POOL_ID}"
      ASSOCIATES_POOL_ID = "${var.ASSOCIATE_USER_POOL_ID}"
    }
  }
}

resource "aws_lambda_permission" "lambda-authorizer" {
  function_name = "${aws_lambda_function.lambda-authorizer.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "lambda-authorizer_POST" {
  rest_api_id   = "${var.API_ID}"
  resource_id   = "${aws_api_gateway_resource.lambda-authorizer.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda-authorizer_integrationa" {
  rest_api_id             = "${var.API_ID}"
  resource_id             = "${aws_api_gateway_resource.lambda-authorizer.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.lambda-authorizer.invoke_arn}"
}

module "CORS_LAMBDA_AUTHORIZER" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.lambda-authorizer.id}"
  rest_api_id = "${var.API_ID}"
}


resource "aws_api_gateway_resource" "associate-authorizer" {
  rest_api_id = "${var.API_ID}"
  parent_id   = "${var.ROOT_RESOURCE_ID}"
  path_part   = "associate-authorizer"
}

resource "aws_lambda_function" "associate-authorizer" {
  filename         = "lambda-authorizer.zip"
  function_name    = "associate-authorizer"
  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/associate-authorizer.handler"
  source_code_hash = "${base64sha256(file("lambda-authorizer.zip"))}"
  runtime          = "nodejs8.10"
  timeout          = 28

  vpc_config {
    subnet_ids = [
      "${var.subnet_id_primary[var.REGION]}",
      "${var.subnet_id_secondary[var.REGION]}",
    ]

    security_group_ids = [
      "${var.security_group[var.REGION]}",
    ]
  }

  tags {
    CostCenter = 67606
    System     = "Portal"
    Region     = "${var.REGION}"
  }

  environment {
    variables = {
      ASSOCIATES_POOL_ID = "${var.ASSOCIATE_USER_POOL_ID}"
      GENERAL_USER_APIS = "customer,consumer-link,associate-multiple-registrations,reset-password"
      ACCOUNT_USER_APIS = "customer,manage-tax-years,associate-multiple-registrations"
      INSURANCE_USER_APIS = "customer,consumer-link,contract-block-search,contract-block-delete,contract-block-add,contract-block-update,associate-consumer-search,associate-delete-users,idproof-skip-search,idproof-skip,associate-multiple-registrations,reset-password"
    }
  }
}

resource "aws_lambda_permission" "associate-authorizer" {
  function_name = "${aws_lambda_function.associate-authorizer.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "associate-authorizer_POST" {
  rest_api_id   = "${var.API_ID}"
  resource_id   = "${aws_api_gateway_resource.associate-authorizer.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "associate-authorizer_integrationa" {
  rest_api_id             = "${var.API_ID}"
  resource_id             = "${aws_api_gateway_resource.associate-authorizer.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.associate-authorizer.invoke_arn}"
}

module "CORS_ASSOCIATE_AUTHORIZER" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.associate-authorizer.id}"
  rest_api_id = "${var.API_ID}"
}

resource "aws_api_gateway_resource" "customer-producer-authorizer" {
  rest_api_id = "${var.API_ID}"
  parent_id   = "${var.ROOT_RESOURCE_ID}"
  path_part   = "customer-producer-authorizer"
}

resource "aws_lambda_function" "customer-producer-authorizer" {
  filename         = "lambda-authorizer.zip"
  function_name    = "customer-producer-authorizer"
  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/customer-producer-authorizer.handler"
  source_code_hash = "${base64sha256(file("lambda-authorizer.zip"))}"
  runtime          = "nodejs8.10"
  timeout          = 28

  vpc_config {
    subnet_ids = [
      "${var.subnet_id_primary[var.REGION]}",
      "${var.subnet_id_secondary[var.REGION]}",
    ]

    security_group_ids = [
      "${var.security_group[var.REGION]}",
    ]
  }

  tags {
    CostCenter = 67606
    System     = "Portal"
    Region     = "${var.REGION}"
  }

  environment {
   variables = {
      CONSUMER_POOL_ID   = "${var.CUSTOMER_USER_POOL_ID}"
      PRODUCER_POOL_ID   = "${var.PRODUCER_USER_POOL_ID}"
    }
  }
}

resource "aws_lambda_permission" "customer-producer-authorizer" {
  function_name = "${aws_lambda_function.customer-producer-authorizer.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "customer-producer-authorizer_POST" {
  rest_api_id   = "${var.API_ID}"
  resource_id   = "${aws_api_gateway_resource.customer-producer-authorizer.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "customer-producer-authorizer_integrationa" {
  rest_api_id             = "${var.API_ID}"
  resource_id             = "${aws_api_gateway_resource.customer-producer-authorizer.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.customer-producer-authorizer.invoke_arn}"
}

module "CORS_CUSTOMER_PRODUCER_AUTHORIZER" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.customer-producer-authorizer.id}"
  rest_api_id = "${var.API_ID}"
}
