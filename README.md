# concat-files

A shell script that concatenates files from specified paths into larger files, with support for Maven cleaning and file exclusion patterns.

Contributions welcome.

## Usage

```
Usage: ./concat-files/concat-files.sh [--mvnclean] [--shallow|-s] [--excludes|-e ant-pattern]... [path...]
Concatenates files from the specified paths (or current directory if none provided).
Paths can be directories or files:
  directory         Include files recursively from the directory (unless --shallow is active)
  file             Include the specified file directly
Options:
  --mvnclean       Search for pom.xml from each directory and run mvn clean once per unique pom.xml
  --shallow|-s     Include only top-level files from subsequent directories
  --excludes|-e pattern  Exclude files matching the Ant-style path expression (e.g., --excludes **/*.txt)
```

## Example

```
./concat-files.sh --shallow --excludes **/*.txt test/test1 file1.java
```

This command:
- Concatenates top-level files from `test/test1` (due to `--shallow`)
- Includes `file1.java` directly
- Excludes any files matching `**/*.txt`
- Creates files like `./test-part1.txt`, `./test-part2.txt`, etc., if the total character count exceeds 100,000

The output file(s) will have the following structure:

```
concatenated sources
---------------------------------------------
file test/test1/fileA.java:
[Content of fileA.java]
---------------------------------------------
file file1.java:
[Content of file1.java]
---------------------------------------------
```

Each output file starts with a header, followed by sections for each included file, separated by a line of dashes, with a maximum of 100,000 characters per file.

## Installation

Add the script as a Git submodule to your project:

```bash
git submodule add https://github.com/qudtlib/concat-files concat-files
```

Then, use it as:

```bash
./concat-files/concat-files.sh [options] [paths...]
```