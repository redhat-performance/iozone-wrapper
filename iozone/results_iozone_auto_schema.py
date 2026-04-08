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
	incache_fsync = "incache+fsync"
	incache_mmap = "incache+mmap"
	outcache = "outcache"

class Iozone_Results (pydantic.BaseModel):
	fs: Filesys
	mode: Testmode
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
	fwrite: float = pydantic.Field()
	frewrite: float = pydantic.Field()
	fread: float = pydantic.Field()
	freread: float = pydantic.Field()
	Start_Date: datetime.datetime
	End_Date: datetime.datetime
