# Tabletop Club Documentation

The documentation is built using [Sphinx](https://www.sphinx-doc.org/en/master/).

## Requirements

To build the documentation, you will need to install a few Python packages,
which you can do with the following command:

```bash
python3 -m pip install -r requirements.txt
```

## Building

To build the documentation on macOS and Linux:
```bash
make html
```

To build the documentation on Windows:
```bash
make.bat html
```

You can then visit the documentation by opening `_build/html/index.html` in the web browser of your choice.

## Cleaning

To clean the build files on macOS and Linux:
```bash
make clean
```

To clean the build files on Windows:
```bash
make.bat clean
```
