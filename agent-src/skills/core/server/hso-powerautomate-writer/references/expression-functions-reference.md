# Expression Functions Reference

Complete reference of expression functions available in Power Automate / Logic Apps workflow definitions.

**Official docs**: https://learn.microsoft.com/en-us/azure/logic-apps/expression-functions-reference

---

## Expression Syntax

- Prefix with `@`: `"@utcNow()"`
- String interpolation: `"@{expression}"` inside a string
- Escape literal `@`: use `@@`
- Null-safe property access: `?['property']`
- Functions are case-sensitive

---

## String Functions

| Function | Description | Example |
|----------|-------------|---------|
| `concat(s1, s2, ...)` | Combine strings | `concat('Hello', ' ', 'World')` → `"Hello World"` |
| `substring(text, start, length?)` | Extract substring | `substring('Hello', 0, 3)` → `"Hel"` |
| `replace(text, old, new)` | Replace substring | `replace('Hello', 'llo', 'y')` → `"Hey"` |
| `split(text, delimiter)` | Split to array | `split('a,b,c', ',')` → `["a","b","c"]` |
| `trim(text)` | Remove whitespace | `trim('  hello  ')` → `"hello"` |
| `toLower(text)` | Lowercase | `toLower('HELLO')` → `"hello"` |
| `toUpper(text)` | Uppercase | `toUpper('hello')` → `"HELLO"` |
| `indexOf(text, search)` | Find position (0-indexed) | `indexOf('hello', 'lo')` → `3` |
| `lastIndexOf(text, search)` | Last occurrence position | `lastIndexOf('hello hello', 'hello')` → `6` |
| `startsWith(text, search)` | Check prefix | `startsWith('hello', 'he')` → `true` |
| `endsWith(text, search)` | Check suffix | `endsWith('hello', 'lo')` → `true` |
| `length(text)` | String length | `length('hello')` → `5` |
| `guid(format?)` | Generate GUID | `guid()` → `"c2ecc88d-..."` |
| `slice(text, start, end?)` | Extract by position | `slice('hello', 1, 3)` → `"el"` |
| `nthIndexOf(text, search, n)` | Nth occurrence | `nthIndexOf('a.b.c', '.', 2)` → `3` |
| `chunk(text, length)` | Split into chunks | `chunk('abcdef', 2)` → `["ab","cd","ef"]` |
| `formatNumber(num, format, locale?)` | Format number | `formatNumber(1234.5, 'N2')` → `"1,234.50"` |
| `isFloat(text, locale?)` | Check if float string | `isFloat('3.14')` → `true` |
| `isInt(text)` | Check if int string | `isInt('42')` → `true` |

---

## Collection Functions

| Function | Description | Example |
|----------|-------------|---------|
| `length(array)` | Array length | `length(createArray(1,2,3))` → `3` |
| `empty(collection)` | Check if empty | `empty('')` → `true` |
| `first(collection)` | First element | `first(createArray(1,2,3))` → `1` |
| `last(collection)` | Last element | `last(createArray(1,2,3))` → `3` |
| `contains(collection, value)` | Check membership | `contains(createArray(1,2,3), 2)` → `true` |
| `join(array, delimiter)` | Join to string | `join(createArray('a','b'), ',')` → `"a,b"` |
| `skip(array, count)` | Skip items | `skip(createArray(1,2,3), 1)` → `[2,3]` |
| `take(array, count)` | Take items | `take(createArray(1,2,3), 2)` → `[1,2]` |
| `union(arr1, arr2, ...)` | Merge arrays | `union(createArray(1,2), createArray(2,3))` → `[1,2,3]` |
| `intersection(arr1, arr2)` | Common items | `intersection(createArray(1,2), createArray(2,3))` → `[2]` |
| `sort(array)` | Sort array | `sort(createArray(3,1,2))` → `[1,2,3]` |
| `reverse(array)` | Reverse order | `reverse(createArray(1,2,3))` → `[3,2,1]` |
| `item()` | Current loop item | `item()?['name']` (in Foreach) |
| `items(loopName)` | Named loop item | `items('My_Loop')?['id']` |

---

## Logical / Comparison Functions

| Function | Description | Example |
|----------|-------------|---------|
| `equals(a, b)` | Equality check | `equals(1, 1)` → `true` |
| `greater(a, b)` | a > b | `greater(5, 3)` → `true` |
| `greaterOrEquals(a, b)` | a >= b | `greaterOrEquals(5, 5)` → `true` |
| `less(a, b)` | a < b | `less(3, 5)` → `true` |
| `lessOrEquals(a, b)` | a <= b | `lessOrEquals(5, 5)` → `true` |
| `and(expr1, expr2, ...)` | All true | `and(true, true)` → `true` |
| `or(expr1, expr2, ...)` | Any true | `or(true, false)` → `true` |
| `not(expr)` | Negate | `not(true)` → `false` |
| `if(expr, trueVal, falseVal)` | Conditional value | `if(equals(1,1), 'yes', 'no')` → `"yes"` |
| `coalesce(val1, val2, ...)` | First non-null | `coalesce(null, 'default')` → `"default"` |

---

## Conversion Functions

| Function | Description | Example |
|----------|-------------|---------|
| `string(value)` | Convert to string | `string(42)` → `"42"` |
| `int(value)` | Convert to integer | `int('42')` → `42` |
| `float(value, locale?)` | Convert to float | `float('3.14')` → `3.14` |
| `bool(value)` | Convert to boolean | `bool(1)` → `true` |
| `decimal(value)` | Convert to decimal | `decimal('3.14159')` |
| `json(value)` | Parse JSON string | `json('{"a":1}')` → `{"a":1}` |
| `xml(value)` | Parse XML string | `xml('<root/>')` |
| `array(value)` | Wrap in array | `array('hello')` → `["hello"]` |
| `createArray(v1, v2, ...)` | Create array | `createArray(1, 2, 3)` → `[1,2,3]` |
| `base64(value)` | Base64 encode | `base64('hello')` |
| `base64ToBinary(value)` | Base64 to binary | |
| `base64ToString(value)` | Base64 decode | `base64ToString('aGVsbG8=')` → `"hello"` |
| `binary(value)` | String to binary | |
| `dataUri(value)` | Create data URI | |
| `dataUriToBinary(value)` | Data URI to binary | |
| `dataUriToString(value)` | Data URI to string | |
| `encodeUriComponent(value)` | URL encode | `encodeUriComponent('hello world')` |
| `decodeUriComponent(value)` | URL decode | `decodeUriComponent('hello%20world')` |
| `uriComponent(value)` | URL encode | same as encodeUriComponent |

---

## Math Functions

| Function | Description | Example |
|----------|-------------|---------|
| `add(a, b)` | Addition | `add(1, 2)` → `3` |
| `sub(a, b)` | Subtraction | `sub(5, 3)` → `2` |
| `mul(a, b)` | Multiplication | `mul(2, 3)` → `6` |
| `div(a, b)` | Division | `div(10, 2)` → `5` |
| `mod(a, b)` | Modulo | `mod(7, 3)` → `1` |
| `min(n1, n2, ...)` / `min([array])` | Minimum value | `min(1, 2, 3)` → `1` |
| `max(n1, n2, ...)` / `max([array])` | Maximum value | `max(1, 2, 3)` → `3` |
| `rand(min, max)` | Random integer | `rand(1, 100)` |
| `range(start, count)` | Integer array | `range(1, 4)` → `[1,2,3,4]` |

---

## Date and Time Functions

| Function | Description | Example |
|----------|-------------|---------|
| `utcNow(format?)` | Current UTC timestamp | `utcNow()` → `"2026-03-19T..."` |
| `formatDateTime(ts, format?, locale?)` | Format timestamp | `formatDateTime(utcNow(), 'yyyy-MM-dd')` |
| `addDays(ts, days, format?)` | Add days | `addDays(utcNow(), 7)` |
| `addHours(ts, hours, format?)` | Add hours | `addHours(utcNow(), 2)` |
| `addMinutes(ts, min, format?)` | Add minutes | `addMinutes(utcNow(), 30)` |
| `addSeconds(ts, sec, format?)` | Add seconds | |
| `addToTime(ts, interval, unit, format?)` | Add time units | `addToTime(utcNow(), 1, 'Week')` |
| `subtractFromTime(ts, interval, unit, format?)` | Subtract time | `subtractFromTime(utcNow(), 1, 'Day')` |
| `getFutureTime(interval, unit, format?)` | Future timestamp | `getFutureTime(1, 'Hour')` |
| `getPastTime(interval, unit, format?)` | Past timestamp | `getPastTime(7, 'Day')` |
| `startOfDay(ts, format?)` | Start of day | `startOfDay(utcNow())` |
| `startOfHour(ts, format?)` | Start of hour | |
| `startOfMonth(ts, format?)` | Start of month | |
| `dayOfMonth(ts)` | Day of month (1-31) | `dayOfMonth(utcNow())` → `19` |
| `dayOfWeek(ts)` | Day of week (0=Sun) | `dayOfWeek(utcNow())` |
| `dayOfYear(ts)` | Day of year (1-366) | |
| `ticks(ts)` | Ticks value | |
| `dateDifference(start, end)` | Time difference | `dateDifference('2026-01-01', '2026-03-19')` |
| `convertFromUtc(ts, tz, format?)` | UTC to timezone | `convertFromUtc(utcNow(), 'Eastern Standard Time')` |
| `convertToUtc(ts, tz, format?)` | Timezone to UTC | |
| `convertTimeZone(ts, srcTz, destTz, format?)` | Between timezones | |
| `parseDateTime(ts)` | Parse timestamp | |

**Time units**: `Second`, `Minute`, `Hour`, `Day`, `Week`, `Month`, `Year`

**Format specifiers** (common):
- `yyyy-MM-dd` → `2026-03-19`
- `yyyy-MM-ddTHH:mm:ssZ` → `2026-03-19T14:30:00Z`
- `MM/dd/yyyy` → `03/19/2026`
- `HH:mm:ss` → `14:30:00`
- `dddd` → `Wednesday`
- `MMMM` → `March`

---

## Workflow Functions

| Function | Description | Example |
|----------|-------------|---------|
| `trigger()` | Trigger output object | `trigger().outputs` |
| `triggerBody()` | Trigger body | `triggerBody()?['field']` |
| `triggerOutputs()` | Trigger outputs | `triggerOutputs()?['body/accountid']` |
| `actions(name)` | Action output | `actions('My_Action').outputs` |
| `body(name)` | Action body | `body('My_Action')?['field']` |
| `outputs(name)` | Action outputs | `outputs('My_Action')?['body/value']` |
| `result(scopeName)` | Scope results | `result('Try_Scope')` |
| `variables(name)` | Variable value | `variables('Counter')` |
| `parameters(name)` | Parameter value | `parameters('$authentication')` |
| `workflow()` | Workflow info | `workflow().name`, `workflow().run.name` |
| `listCallbackUrl()` | Callback URL | For webhook triggers |
| `iterationIndexes(loopName)` | Loop index (Until only) | `iterationIndexes('My_Until')` |

---

## JSON / Object Manipulation

| Function | Description | Example |
|----------|-------------|---------|
| `addProperty(obj, prop, val)` | Add property | `addProperty(json('{}'), 'name', 'test')` |
| `removeProperty(obj, prop)` | Remove property | `removeProperty(variables('obj'), 'temp')` |
| `setProperty(obj, prop, val)` | Set property | `setProperty(variables('obj'), 'status', 'done')` |
| `xpath(xml, expr)` | XPath query | `xpath(xml(body('Get_XML')), '//name')` |

---

## URI Functions

| Function | Description |
|----------|-------------|
| `uriHost(uri)` | Extract host |
| `uriPath(uri)` | Extract path |
| `uriPathAndQuery(uri)` | Extract path + query |
| `uriPort(uri)` | Extract port |
| `uriQuery(uri)` | Extract query string |
| `uriScheme(uri)` | Extract scheme (http/https) |

---

## Common Expression Patterns for Dataverse Flows

### Null-safe field access
```
@triggerOutputs()?['body/name']
@outputs('Get_Record')?['body/emailaddress1']
```

### Conditional value (inline if)
```
@if(empty(triggerOutputs()?['body/description']), 'No description', triggerOutputs()?['body/description'])
```

### Lookup binding with null check
```
@if(empty(triggerOutputs()?['body/_parentaccountid_value']), null, concat('accounts(', triggerOutputs()?['body/_parentaccountid_value'], ')'))
```

### String interpolation
```
@{triggerOutputs()?['body/name']} | Created | @{formatDateTime(utcNow(), 'MM/dd/yyyy')}
```

### Array length check
```
@length(outputs('List_rows')?['body/value'])
```

### Format date from trigger
```
@formatDateTime(triggerOutputs()?['body/createdon'], 'MM/dd/yyyy')
```

### Concatenate with null handling
```
@concat(coalesce(triggerOutputs()?['body/firstname'], ''), ' ', coalesce(triggerOutputs()?['body/lastname'], ''))
```
