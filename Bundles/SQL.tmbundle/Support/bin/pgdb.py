# $Id: pgdb.py,v 1.29 2005/08/25 13:52:59 cito Exp $

"""pgdb - DB-API 2.0 compliant module for PygreSQL.

	(c) 1999, Pascal Andre <andre@via.ecp.fr>.
	See package documentation for further information on copyright.

	Inline documentation is sparse.
	See DB-API 2.0 specification for usage information:
	http://www.python.org/peps/pep-0249.html

	Basic usage:

	pgdb.connect(connect_string) # open a connection
	# connect_string = 'host:database:user:password:opt:tty'
	# All parts are optional. You may also pass host through
	# password as keyword arguments. To pass a port,
	# pass it in the host keyword parameter:
	pgdb.connect(host='localhost:5432')

	connection.cursor() # open a cursor

	cursor.execute(query[, params])
	# Execute a query, binding params (a dictionary) if they are
	# passed. The binding syntax is the same as the % operator
	# for dictionaries, and no quoting is done.

	cursor.executemany(query, list of params)
	# Execute a query many times, binding each param dictionary
	# from the list.

	cursor.fetchone() # fetch one row, [value, value, ...]

	cursor.fetchall() # fetch all rows, [[value, value, ...], ...]

	cursor.fetchmany([size])
	# returns size or cursor.arraysize number of rows,
	# [[value, value, ...], ...] from result set.
	# Default cursor.arraysize is 1.

	cursor.description # returns information about the columns
	#	[(column_name, type_name, display_size,
	#		internal_size, precision, scale, null_ok), ...]
	# Note that precision, scale and null_ok are not implemented.

	cursor.rowcount # number of rows available in the result set
	# Available after a call to execute.

	connection.commit() # commit transaction

	connection.rollback() # or rollback transaction

	cursor.close() # close the cursor

	connection.close() # close the connection

"""

import string
import types
import time

from _pg import *

try: # use mx.DateTime module if available
	from mx.DateTime import DateTime, \
		TimeDelta, DateTimeType
except ImportError: # otherwise use standard datetime module
	from datetime import datetime as DateTime, \
		timedelta as TimeDelta, datetime as DateTimeType

### module constants

# compliant with DB SIG 2.0
apilevel = '2.0'

# module may be shared, but not connections
threadsafety = 1

# this module use extended python format codes
paramstyle = 'pyformat'

### internal type handling class

class pgdbTypeCache:

	def __init__(self, cnx):
		self.__source = cnx.source()
		self.__type_cache = {}

	def typecast(self, typ, value):
		# for NULL values, no typecast is necessary
		if value == None:
			return value

		if typ == STRING:
			pass
		elif typ == BINARY:
			pass
		elif typ == BOOL:
			value = (value[:1] in ['t','T'])
		elif typ == INTEGER:
			value = int(value)
		elif typ == LONG:
			value = long(value)
		elif typ == FLOAT:
			value = float(value)
		elif typ == MONEY:
			value = string.replace(value, "$", "")
			value = string.replace(value, ",", "")
			value = float(value)
		elif typ == DATETIME:
			# format may differ ... we'll give string
			pass
		elif typ == ROWID:
			value = long(value)
		return value

	def getdescr(self, oid):
		try:
			return self.__type_cache[oid]
		except:
			self.__source.execute(
				"SELECT typname, typlen "
				"FROM pg_type WHERE oid = %s" % oid
			)
			res = self.__source.fetch(1)[0]
			# column name is omitted from the return value. It will
			# have to be prepended by the caller.
			res = (
				res[0],
				None, string.atoi(res[1]),
				None, None, None
			)
			self.__type_cache[oid] = res
			return res

### cursor object

class pgdbCursor:

	def __init__(self, src, cache):
		self.__cache = cache
		self.__source = src
		self.description = None
		self.rowcount = -1
		self.arraysize = 1
		self.lastrowid = None

	def close(self):
		self.__source.close()
		self.description = None
		self.rowcount = -1
		self.lastrowid = None

	def arraysize(self, size):
		self.arraysize = size

	def execute(self, operation, params = None):
		# "The parameters may also be specified as list of
		# tuples to e.g. insert multiple rows in a single
		# operation, but this kind of usage is deprecated:
		if params and isinstance(params, types.ListType) and \
					isinstance(params[0], types.TupleType):
			self.executemany(operation, params)
		else:
			# not a list of tuples
			self.executemany(operation, (params,))

	def executemany(self, operation, param_seq):
		self.description = None
		self.rowcount = -1

		# first try to execute all queries
		totrows = 0
		sql = "INIT"
		try:
			for params in param_seq:
				if params != None:
					sql = _quoteparams(operation, params)
				else:
					sql = operation
				rows = self.__source.execute(sql)
				if rows != None: # true if __source is not DML
					totrows += rows
				else:
					self.rowcount = -1
		except Error, msg:
			raise DatabaseError, "error '%s' in '%s'" % ( msg, sql )
		except Exception, err:
			raise OperationalError, "internal error in '%s': %s" % (sql,err)
		except:
			raise OperationalError, "internal error in '%s'" % sql

		# then initialize result raw count and description
		if self.__source.resulttype == RESULT_DQL:
			self.rowcount = self.__source.ntuples
			d = []
			for typ in self.__source.listinfo():
				# listinfo is a sequence of
				# (index, column_name, type_oid)
				# getdescr returns all items needed for a
				# description tuple except the column_name.
				desc = typ[1:2]+self.__cache.getdescr(typ[2])
				d.append(desc)
			self.description = d
			self.lastrowid = self.__source.oidstatus()
		else:
			self.rowcount = totrows
			self.description = None
			self.lastrowid = self.__source.oidstatus()

	def fetchone(self):
		res = self.fetchmany(1, 0)
		try:
			return res[0]
		except:
			return None

	def fetchall(self):
		return self.fetchmany(-1, 0)

	def fetchmany(self, size = None, keep = 0):
		if size == None:
			size = self.arraysize
		if keep == 1:
			self.arraysize = size

		try: res = self.__source.fetch(size)
		except Error, e: raise DatabaseError, str(e)

		result = []
		for r in res:
			row = []
			for i in range(len(r)):
				row.append(self.__cache.typecast(
						self.description[i][1],
						r[i]
					)
				)
			result.append(row)
		return result

	def nextset(self):
		raise NotSupportedError, "nextset() is not supported"

	def setinputsizes(self, sizes):
		pass

	def setoutputsize(self, size, col = 0):
		pass


class _quoteitem(dict):
	def __getitem__(self, key):
		return _quote(super(_quoteitem, self).__getitem__(key))

def _quote(x):
	if isinstance(x, DateTimeType):
		x = str(x)
	elif isinstance(x, unicode):
		x = x.encode( 'utf-8' )

	if isinstance(x, types.StringType):
		x = "'" + string.replace(
			string.replace(str(x), '\\', '\\\\'), "'", "''") + "'"
	elif isinstance(x, (types.IntType, types.LongType, types.FloatType)):
		pass
	elif x is None:
		x = 'NULL'
	elif isinstance(x, (types.ListType, types.TupleType)):
		x = '(%s)' % string.join(map(lambda x: str(_quote(x)), x), ',')
	elif hasattr(x, '__pg_repr__'):
		x = x.__pg_repr__()
	else:
		raise InterfaceError, 'do not know how to handle type %s' % type(x)

	return x

def _quoteparams(s, params):
	if hasattr(params, 'has_key'):
		params = _quoteitem(params)
	else:
		params = tuple(map(_quote, params))

	return s % params

### connection object

class pgdbCnx:

	def __init__(self, cnx):
		self.__cnx = cnx
		self.__cache = pgdbTypeCache(cnx)
		try:
			src = self.__cnx.source()
			src.execute("BEGIN")
		except:
			raise OperationalError, "invalid connection."

	def close(self):
		self.__cnx.close()

	def commit(self):
		try:
			src = self.__cnx.source()
			src.execute("COMMIT")
			src.execute("BEGIN")
		except:
			raise OperationalError, "can't commit."

	def rollback(self):
		try:
			src = self.__cnx.source()
			src.execute("ROLLBACK")
			src.execute("BEGIN")
		except:
			raise OperationalError, "can't rollback."

	def cursor(self):
		try:
			src = self.__cnx.source()
			return pgdbCursor(src, self.__cache)
		except:
			raise OperationalError, "invalid connection."

### module interface

# connects to a database
_connect_ = connect
def connect(dsn = None,
	user = None, password = None,
	host = None, database = None):
	# first get params from DSN
	dbport = -1
	dbhost = ""
	dbbase = ""
	dbuser = ""
	dbpasswd = ""
	dbopt = ""
	dbtty = ""
	try:
		params = string.split(dsn, ":")
		dbhost = params[0]
		dbbase = params[1]
		dbuser = params[2]
		dbpasswd = params[3]
		dbopt = params[4]
		dbtty = params[5]
	except:
		pass

	# override if necessary
	if user != None:
		dbuser = user
	if password != None:
		dbpasswd = password
	if database != None:
		dbbase = database
	if host != None:
		try:
			params = string.split(host, ":")
			dbhost = params[0]
			dbport = int(params[1])
		except:
			pass

	# empty host is localhost
	if dbhost == "":
		dbhost = None
	if dbuser == "":
		dbuser = None

	# open the connection
	cnx = _connect_(dbbase, dbhost, dbport, dbopt,
		dbtty, dbuser, dbpasswd)
	return pgdbCnx(cnx)

### types handling

# PostgreSQL is object-oriented: types are dynamic.
# We must thus use type names as internal type codes.

class pgdbType:

	def __init__(self, *values):
		self.values=  values

	def __cmp__(self, other):
		if other in self.values:
			return 0
		if other < self.values:
			return 1
		else:
			return -1

STRING = pgdbType(
	'char', 'bpchar', 'name', 'text', 'varchar'
)

# BLOB support is pg specific
BINARY = pgdbType()
INTEGER = pgdbType('int2', 'int4', 'serial')
NUMBER = pgdbType('int2', 'int4', 'serial', 'int8', 'float4', 'float8', 'numeric')
LONG = pgdbType('int8')
FLOAT = pgdbType('float4', 'float8', 'numeric')
BOOL = pgdbType('bool')
MONEY = pgdbType('money')

# this may be problematic as type are quite different ... I hope it won't hurt
DATETIME = pgdbType(
	'abstime', 'reltime', 'tinterval', 'date', 'time', 'timespan', 'timestamp', 'timestamptz', 'interval'
)

# OIDs are used for everything (types, tables, BLOBs, rows, ...). This may cause
# confusion, but we are unable to find out what exactly is behind the OID (at
# least not easily enough). Should this be undefined as BLOBs ?
ROWID = pgdbType(
	'oid', 'oid8'
)

# mandatory type helpers
def Date(year, month, day):
	return DateTime(year, month, day)

def Time(hour, minute, second):
	return TimeDelta(hour, minute, second)

def Timestamp(year, month, day, hour, minute, second):
	return DateTime(year, month, day, hour, minute, second)

def DateFromTicks(ticks):
	return apply(Date, time.localtime(ticks)[:3])

def TimeFromTicks(ticks):
	return apply(Time, time.localtime(ticks)[3:6])

def TimestampFromTicks(ticks):
	return apply(Timestamp, time.localtime(ticks)[:6])
