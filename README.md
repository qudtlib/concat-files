# concat-files

A shell script that makes it easy to select a few files and concat them into larger files

Contributions welcome.

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