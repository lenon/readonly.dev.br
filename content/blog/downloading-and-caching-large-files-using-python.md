---
title: "Downloading and caching large files using Python"
date: 2021-05-24T22:00:00Z
tags: [python,http]
---

While writing a small Python library to download and parse a large CSV file from
the web, I had to implement a strategy to cache the file locally and avoid
downloading it on every execution. I wanted the library to download the file
only once on the first execution and also when it has changed on the server. In
this blog post I'm describing how to implement this with Python, basic HTTP
headers and file manipulation.

Let's start by looking at these two HTTP headers used to control cache:

* `Last-Modified`: according to [MDN][mdn-last-modified], this is a response
  header sent by HTTP servers and it "contains the date and time at which the
  origin server believes the resource was last modified".
* `If-Modified-Since`: also according to [MDN][mdn-if-modified-since], this is a
  request header and it "makes the request conditional: the server will send
  back the requested resource, with a 200 status, only if it has been last
  modified after the given date. If the resource has not been modified since,
  the response will be a 304 without any body".

So I can store the value of `Last-Modified` and send it in the next HTTP request
as the value for `If-Modified-Since`. The server will return a 200 status and a
body only if the file has been modified.

Both headers contain a timestamp in the format defined by [RFC 7231][rfc7231] as
an "HTTP-date" and Python has functions to handle this format. They can be
imported from the module `email.utils` and, despite the module name, are
compatible with the HTTP standard. Here's an example:

```python
from datetime import datetime
from email.utils import parsedate_to_datetime, formatdate

formatdate(datetime.now().timestamp(), usegmt=True)
# 'Sat, 22 May 2021 03:08:49 GMT'

parsedate_to_datetime('Sat, 22 May 2021 03:08:49 GMT')
# datetime.datetime(2021, 5, 22, 3, 8, 49, tzinfo=datetime.timezone.utc)
```

It is important to pass `usegmt=True` to `formatdate` because HTTP dates are
always expressed in GMT.

I can use file's modification time (`mtime`) to store the modification time
indicated by the HTTP response. Python has
[`os.path.getmtime`][python-os-path-getmtime] to get modification time and
[`os.utime`][python-os-utime] to change it:

```python
import os
from datetime import datetime

os.utime("hello.txt", times=(datetime.now().timestamp(), 1621653735.0))
os.path.getmtime("hello.txt")
# 1621653735.0
```

Now, let's see the actual download function. I've used
[requests][python-requests] to make the HTTP request as follows:

```python
import os
import requests
from datetime import datetime
from email.utils import parsedate_to_datetime, formatdate

def download(url, destination_file):
    headers = {}

    if os.path.exists(destination_file):
        mtime = os.path.getmtime(destination_file)
        headers["if-modified-since"] = formatdate(mtime, usegmt=True)

    response = requests.get(url, headers=headers, stream=True)
    response.raise_for_status()

    if response.status_code == requests.codes.not_modified:
        return

    if response.status_code == requests.codes.ok:
        with open(destination_file, "wb") as f:
            for chunk in response.iter_content(chunk_size=1048576):
                f.write(chunk)

        if last_modified := response.headers.get("last-modified"):
            new_mtime = parsedate_to_datetime(last_modified).timestamp()
            os.utime(destination_file, times=(datetime.now().timestamp(), new_mtime))
```

Here's some important parts of this function:

* `response.raise_for_status()` will raise an error for 4xx (client errors) or
  5xx (server errors).
* `requests.get(..., stream=True)` and
  `response.iter_content(chunk_size=1048576)` are used to iterate over the
  response data and are important to avoid reading the full dataset into memory.
  `chunk_size` is the number of bytes which is, in this case, 1 MiB.

The `download` function can be used like this:

```python
dataset_url = "https://www.tesourotransparente.gov.br/ckan/dataset/df56aa42-484a-4a59-8184-7676580c81e3/resource/796d2059-14e9-44e3-80c9-2d9e30b405c1/download/PrecoTaxaTesouroDireto.csv"

download(dataset_url, "dataset.csv")
```

Calling it multiple times will update the dataset only if it has changed on the
server, as expected. Depending on the situation, it would be good to also
implement a check on the `Cache-Control` header, but for now this is good
enough.

[mdn-last-modified]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Last-Modified
[mdn-if-modified-since]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Modified-Since
[rfc7231]: https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.1.1
[python-requests]: https://docs.python-requests.org/
[python-os-path-getmtime]: https://docs.python.org/3/library/os.path.html#os.path.getmtime
[python-os-utime]: https://docs.python.org/3/library/os.html#os.utime
