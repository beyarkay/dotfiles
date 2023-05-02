# `mp` - Quickly create the outline of a project based on a template


Templates are defined in YAML, and describe the directory structure, initial
files, what options should be requested, etc.

Each yaml file is a few items about invoking the template, and then a series of
steps that must be taken. Steps are ordered actions such as "run this command",
"create this directory", "create this file with these contents", or similar.

Create a new project from the report template and prompt for all details
```
$ mp report
```

Create a new project, but put all the files in the current directory (as
opposed to creating a new directory and putting them in there):
```
$ mp report --here
$ mp report --dir=.
```

### Creating a new pandoc-happy research project

```yaml
name: "Create a new report project"

```
