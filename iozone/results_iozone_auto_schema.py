import pydantic
import datetime
from enum import Enum
class Filesys(Enum):
	xfs = "xfs"
	ext4 = "ext4"
	ext3 = "ext3"

class Testmode(Enum):
	directio = "directio"
	incache = "incache"
	incache+fsync = "incache+fsync"
	incache+mmap = "incache+mmap"
	outcache = "outcache"

class Iozone_Results (pydantic.BaseModel):
	filesys: Filesys
	testmode: Testmode
	all_ios: int = pydantic.Field(gt=0)
	initwrite: int = pydantic.Field(gt=0)
	rewrite: int = pydantic.Field(gt=0)
	read: int = pydantic.Field(gt=0)
	reread: int = pydantic.Field(gt=0)
	rndread: int = pydantic.Field(gt=0)
	rndwrite: int = pydantic.Field(gt=0)
	backread: int = pydantic.Field(gt=0)
	recrewrite: int = pydantic.Field(gt=0)
	strideread: int = pydantic.Field(gt=0)
	fwrite: int = pydantic.Field(gt=0)
	frewrite: int = pydantic.Field(gt=0)
	fread: int = pydantic.Field(gt=0)
	freread: int = pydantic.Field(gt=0)
	Start_Date: datetime.datetime
	End_Date: datetime.datetime
