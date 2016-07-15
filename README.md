# amd_pathping
Establishes network reliability and routing profiles amongst a network of AMDs.


## Requires
MTR v0.85+ with the 
fix_split-mode pull (#51 https://github.com/traviscross/mtr/pull/51) 
and
fix to split mode not outputting missed hops
	diff --git a/split.c b/split.c
	index 73dc9a3..ad81f7f 100644
	--- a/split.c
	+++ b/split.c
	@@ -140,7 +140,7 @@ void split_open(void)
	 #endif
	   LineCount = -1;
	   for (i=0; i<MAX_LINE_COUNT; i++) {
	-    strcpy(Lines[i], "???");
	+    strcpy(Lines[i], "??");
	   }
	 }
	 
compiled in

