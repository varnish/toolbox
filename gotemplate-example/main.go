package main

import (
	"gopkg.in/yaml.v3"
	"io/ioutil"
	"log"
	"os"
	"text/template"
)

func main() {
	if len(os.Args) != 3 {
		log.Fatalf("Usage: %s YAML_CONFIG VCL_TEMPLATE", os.Args[0])
	}

	// load the YAML file and deserialize it
	yamlFile, err := ioutil.ReadFile(os.Args[1])
	if err != nil {
		log.Fatalf("yamlFile.Get err   #%v ", err)
	}
	var conf interface{}
	err = yaml.Unmarshal(yamlFile, &conf)
	if err != nil {
		log.Fatalf("Unmarshal: %v", err)
	}

	// load the template
	tmpl, err := template.ParseFiles(os.Args[2])
	if err != nil {
		log.Fatalf("tmplFile.Get err   #%v ", err)
	}

	tmpl.Execute(os.Stdout, conf)
}
