# concat-files

A shell script that makes it easy to select a few files and concat them into larger files

Contributions welcome.

## Usage

```
Usage: ./concat-files/concat-files.sh [--mvnclean] [ [nosubdirs:]path...]
Concatenates files from the specified paths (or current directory if none provided).
Paths can be directories or files:
directory         Include files recursively from the directory
nosubdirs:directory  Include only top-level files from the directory
file             Include the specified file directly
Options:
--mvnclean       Search for pom.xml from each directory and run mvn clean once per unique pom.xml
```

## Example

```
./concat-files.sh test/test1
```
creates a file 
`./concat-files-part1.txt`
with the following content
```
concatenated sources
---------------------------------------------
file test/test1/directory1/fileA.txt:
This is fileA.txt
---------------------------------------------
file test/test1/directory1/fileB.txt:
This is fileB.txt
---------------------------------------------
file test/test1/directory2/fileA.txt:
This is fileA.txt
---------------------------------------------
file test/test1/directory2/fileB.txt:
This is fileB.txt
```

... which is just the filenames and content of all files under `./test/test1` 

## Installation

Nothing fancy. I tend to add it as a submodule to the project I need it in:

Go to the root folder of your git-managed project and say
```
git submodule add https://github.com/qudtlib/concat-files concat-files
```

Then, you can use it as 
```
./concat-files/concat-files.sh
```