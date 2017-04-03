<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
  <xsl:template match="/MTR">
  <xsl:variable name="src"><xsl:value-of select="@SRC"></xsl:value-of></xsl:variable>
  <xsl:variable name="dst"><xsl:value-of select="@DST"></xsl:value-of></xsl:variable>
<!--<xsl:text>#source destination hop node sent received lost loss% best average worst stdev geomean jitter avgjitter maxjitter intjitter
</xsl:text>-->

  <xsl:for-each select="/MTR/HOP">
    <xsl:value-of select="normalize-space($src)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space($dst)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(@COUNT)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(@HOST)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Snt)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Rcv)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Drop)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Loss)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Best)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Avg)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Wrst)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(StDev)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Gmean)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Jttr)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Javg)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Jmax)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(Jint)"></xsl:value-of><xsl:text> </xsl:text>
    <xsl:text>
</xsl:text><!-- blank line required -->
  </xsl:for-each>
  
  </xsl:template>
</xsl:stylesheet>