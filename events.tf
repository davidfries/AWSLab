# module "eventbridge" {
#   source = "terraform-aws-modules/eventbridge/aws"
#   create_bus = false
#   policy_json = <<EOF
#   {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "states:StartExecution"
#             ],
#             "Resource": [
#                 "arn:aws:states:us-east-1:651426156482:stateMachine:Reboot"
#             ]
#         }
#     ]
# }
# EOF
# role_name = "smrole"
#   rules = {
#     crons = {
#       description         = "Trigger for system reboot"
#       schedule_expression = "cron(55 14 ? * TUE *)"
#     }
#   }

#   targets = {
#     crons = [
#       {
        
#         arn   = "${aws_sfn_state_machine.sfn_state_machine.arn}"
#         name = "exec_stepfunc"

#       }
#     ]
#   }
# }