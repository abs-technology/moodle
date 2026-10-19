# Adding count to the VM EIP when aws-alb landed. Existing Traefik / IP-direct
# sites keep the same address; Terraform must not replace the Elastic IP.
moved {
  from = aws_eip.moodle
  to   = aws_eip.moodle[0]
}

moved {
  from = aws_eip_association.moodle
  to   = aws_eip_association.moodle[0]
}
