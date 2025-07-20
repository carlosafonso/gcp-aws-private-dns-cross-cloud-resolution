output "test_command" {
  value = "gcloud compute ssh ${google_compute_instance.vm.name} --zone ${google_compute_instance.vm.zone} --command=\"curl -s www.example.foobar | jq -r .\""
}
