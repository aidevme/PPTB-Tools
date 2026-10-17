# Third-party notices

The Dataverse Early-Bound TypeScript Generator includes material from the project below. Its licence and
copyright notice are reproduced as its licence requires.

## dataverse-gen

- **Project:** [dataverse-gen](https://github.com/scottdurow/dataverse-gen), version 2.0.17
- **Author:** Scott Durow
- **Licence:** MIT ([original licence file](https://github.com/scottdurow/dataverse-gen/blob/master/LICENSE))
- **Used in this tool:**
  - The generator logic and the output templates are a TypeScript port of dataverse-gen (`src/core/`); they're
    compiled into the tool's `dist/` bundle.
  - dataverse-gen's seven EJS templates (`_templates/*.ejs`) are included unchanged in
    `src/assets/dataverse-gen-templates/`, bundled into `dist/`, and written into users' projects by Generate.
  - The test fixtures in `test/fixtures/` are trimmed from dataverse-gen's test data, and `test/reference/` holds
    output produced by the dataverse-gen CLI.

```text
MIT License

Copyright (c) 2020 Scott Durow

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Not included

- **[dataverse-ify](https://github.com/scottdurow/dataverse-ify)** (MIT, Scott Durow): the generated code imports
  it, but none of its code is included in this tool. Projects using the generated code install it themselves.
- **[dataverse-auth](https://github.com/scottdurow/dataverse-auth)**: not used or ported; Power Platform ToolBox
  provides the Dataverse connection.
