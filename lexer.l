/*
*Practica 1(Flex): estadisticas de diagramas de clases TikZ-UML en un documento LaTeX.
*
*Uso: ./tikzuml [fichero.tex]
*/

%option noyywrap nounput noinput nodefault

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NOMBRE_MAXIMO 256

enum {SIG_NOMBRE_PAQUETES,SIG_NOMBRE_CLASE,SIG_ATRIBUTOS,SIG_METODOS}

enum {MIEMBRO_VACIO,MIEMBRO_PUBLICA,MIEMBRO_PRIVADA,MIEMBRO_PROTEGIDA,MIEMBRO_OTRA}

/*Variables globales*/

static int num_paquetes=0,nivel=0,nivel_max=0;
static int publicos=0,privados=0,protegidos=0;
static char paquete_largo[NOMBRE_MAXIMO]="";
static int log_paquete =0;
static char clase_max[NOMBRE_MAXIMO]=0;
static int atributo_max=-1;

/*estados de analisis*/
static char clase_actual[NOMBRE_MAXIMO];
static int atributo_max;
static int siguiente;
static int prof;
static int vis;
static int estado_previo;
/*clases a usar*/

static void copiar (char *dst,const char *src);
static int long_uft8(const char *s);
static void marcar(int v);
static void cerrar_miembro();
static void cerrar_clases();

%}


ESPACIOS [\t\r\e]
COMENTARIOS "%".*
ORDEN "\\"[A-Za-z@]+
ESCAPE "\\"(.|\n)
VERB "\\verb""*"?("|"[^|\n]*"|"|"+"[^+\n]*"+"|"!"[^!\n]*"")
INI_VERB "\\begin{verbatim}"
FIN_VERB "\\end{veratim}"
INI_TIKZ "\\begin{tikzpicture}"
END_TIKZ "\\end{tikzpicture}"
INI_PAQUETE "\\begin{umlpackage}"
END_PAQUETE "\\end{umlpackage}"
END_DOC "\\end{document}"
CLASE "\\umlclass"
NOMBRE [^ \t\r%{}\\]+

/*comun dentro y fuera del tikz*/

<INITIAL,TIKZ>{COMENTARIOS}		;
<IITIAL,TIKZ>{VERB}	;
<INITIAL,TIKZ>{INI_VERB}	{estado_previo=YY_START;BEGIN(VERBATIM);}
<INITIAL,TIKZ>{END_DOC}		{yyterminated();}

/* fuera del tikz*/

<INITIAL>{INI_TIKZ}	{BEGIN(INITIAL);}
<INITIAL>{ORDEN}|{ESCAPE}	;
<INITIAL>[^\\%]+	;

/* dentro del tikz*/

<TIKZ>{INI_TIKZ}	{BEGIN(INI_TIKZ);}
<TIKZ>{INI_PAQUETE}	{
			 num_paquete++<
			 if(++nivel>nivel) nivel_max=nivel;
			 siguiente = SIG_NOMBRE_PAQUETE;
			 BEGIN(PRE);
			}
<TIKZ>{END_PAQUETE}	{if(nivel>0) nivel--;}
<TIKZ>{CLASE}/[^A-Za-z@]	{
				 clase_actual[0]='\0';
				 atrib_clase=0;
				 siguiente = SIG_NOMBRE_CLASE;
				 BEGIN(PRE);
				}
<TIKZ>{ORDEN}|{ESCAPE}	;
<TIKZ>[^\\%]+	;

/* Verbatim: solo temina con \end{verbatim}*/

<VERBATIM>{FIN_VERB}	{BEGIN(estado_previo);}
<VERBATIM>[^\\]+"\\"	;


<PRE>{ESPACIOS}+	;
<PRE>{COMENTARIOS}	;
<PRE>"["	{ prof= 0; BEGIN(OPCIONES)'}
<PRE>"{"	{ if( siguiente == SIG_NOMBRE_PAQUETE || siguiente == SIG_NOMBRE_CLASE) 
		  BEGIN(NOMBRE);
		  else{
			prof =0;
			vis = VIS_VACIO;
			BEGIN (MIEMBROS);	
		  }
		}
<PRE>.	{yyless(0); BEGIN(TIKZ); /* entrada inesperada*/}



<OPC>{COMENTARIOS}	;
<OPC>{ESCAPE}		;
<OPC>"{"	{ prof++;}
<OPC>"}"	{ if(prof>0) prof--;}
<OPC>"]"	{ if (prof== 0) BEGIN(PRE);}
<OPC>[^\\%{}\]]+	;


<NOMBRE>{ESPACIOS}+	;
<NOMBRE>{ESCAPE}	;
<NOMBRE>{NOMBRE}	{if(siguiente == SIG_NOMBRE_PAQUETE){
				int l = long_uft8(yytext);
				if(l > long_paquete){
					long_paquete = l;
					copiar(paquete_largo,yytext);
				}
			}else{
				copiar(clase_actual,yytext);	
			}	
			}
<NOMBRE>"}"		{ if(siguiente== SIG_NOMBRE_PAQUETE){
				BEGIN(TIKZ);
			else{
				siguiente= SIG_ATRIBUTOS;
				BEGIN(PRE);	
				}
			}
<NOMBRE>.	;


<MIEMBROS>{COMENTARIOS}	;
<MIEMBROS>{ESPACIOS}+	;
<MIEMBROS>"\\\\"	{ if(prof==0) cerrar_miembro(); else marcar(VIS_OTRA);}
<MIEMBROS>"\\#"		{marcar(VIS_PROTEGIDA);}
<MIEMBROS>"+"		{marcar(VIS_PUBLICA);}
<MIEMBROS>"-"		{marcar(VIS_PRIVADA);}
<MIEMBROS>"{"		{prof++; marcar(VIS_OTRA);}
<MIEMBROS>"}"		{ if (prof>0){
				prof--;
			}else{
				cerrar_meimbro();
				if(siguiente== SIG_ATRIBUTOS){
				siguiente = SIG_METODOS;
				BEGIN(PRE);
			}else{
				cerrar_clase();
				BEGIN(TIKZ);
			}
			}
			}
<MIEMBROS>{ORDEN}|{ESCAPE}	{marcar(VIS_OTRA); /* \{ \} \% \_ \textbf ... */}
<MIEMBROS>[^\\%{}+\- \t\r\n]+	{marcar(VIS_OTRA); }
<MIEMBROS>.			{marcar(VIS_OTRA);}

%%

static void copiar(char *dst, const char *src)
{
	strncpy(dst,src, MAXNOMBRE -1);
	dst[MAXNOMBRE - 1] = '\0';
}

static void int long_utf8(const char *s){
	int n = 0;
	for(; *s; s++){
	 if(((unsigned char)*s & 0xC0) != 0x80) n++;
	}
	return n;
}

static void marcar (int v)
{
	if(vis == VIS_VACIO) vis = v;
	}

}

static void cerrar_miembro(void)
{
	if(vis!=VIS_VACIO){
		if(siguiente == SIG_ATRIBUTOS) atributos++;
		switch(vis){
			case VIS_PUBLICA:	publicos++; break;
			case VIS_PRIVADA:	privados++; break;
			case VIS_PROTEGIDA: 	protegidos++; break;
		}
	}
	vis = VIS_VACIO;
}

static void cerrar_clase()
{
	if (atributo_clase > atributo_max){

	atributo_max = atributo_clase;
	copiar(clase_max,clase_catual);
	}
}

int main (int argc, char *argv[])
{
	if(argc >2){
		fprintf(stderr,"Uso : %s [fichero]\n",argv[0]);
		return EXIT_FAILURE;
	}
	if(argc== 2 && (yyin = fopen(argv[1],"r")) == NULL){
		perror(argv[1]);
		return EXIT_FAILURE;
	}
	yylex();
	printf("Paquetes : %d (anidamientos maximo : %d)\n",num_paquetes,nivel_max);
	printf("Miembros por visibilidad: publicos %d, privados %d, protegidos %d\n",publicos,privados,protegidos);
	if(atrib_max >=0)
		printf("Clases con mas atributos: %s (%d)\n", clase_max,atrib_max);
	else
		printf("Clases con mas atributos : ninguna \n");
	
	if(num_paquete >0)
		printf ("Nombre de paquete mas largo: %s\n",paquete_largo);
	else
		printf ("Nombre de paquete mas largo: ninguno");
	if(yyin != stdin) fclose(yyin);
	return EXIT_SUCCESS;
	}

