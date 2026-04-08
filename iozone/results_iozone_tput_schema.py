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

class Operation(Enum):
	Initialwrite = "Initialwrite"
	Rewrite = "Rewrite"
	Read = "Read"
	Reread =  "Reread"
	ReverseRead = "ReverseRead"
	Strideread = "Strideread"
	Randomread = "Randomread"
	Mixedworkload = "Mixedworkload"
	Randomwrite = "Randomwrite"
	Pwrite = "Pwrite"
	Pread = "Pread"
	Fwrite = "Fwrite"
	Fread = "Fread"

class Iozone_Results (pydantic.BaseModel):
	fs: Filesys
	mode: Testmode
	op: Operation
	proc1: float = pydantic.Field(gt=0, allow_inf_nan=False)
	proc2: float = pydantic.Field(gt=0, allow_inf_nan=False)
	proc4: float = pydantic.Field(gt=0, allow_inf_nan=False)
	Start_Date: datetime.datetime
	End_Date: datetime.datetime

