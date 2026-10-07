import {StreamLanguage} from '@codemirror/language';
export const pseintMode=StreamLanguage.define({token(stream){
 if(stream.eatSpace())return null;
 if(stream.match('//')){stream.skipToEnd();return 'comment'}
 if(stream.match(/"(?:[^"\\]|\\.)*"?|'(?:[^'\\]|\\.)*'?/))return 'string';
 if(stream.match(/\d+(?:\.\d+)?/))return 'number';
 if(stream.match(/\b(?:Algoritmo|FinAlgoritmo|Proceso|FinProceso|Definir|Como|Entero|Real|Cadena|Caracter|Logico|Escribir|Leer|Si|Entonces|SiNo|FinSi|Para|Hasta|Con|Paso|Hacer|FinPara|Mientras|FinMientras|Repetir|Que|Verdadero|Falso|Y|O|NO|MOD)\b/i))return 'keyword';
 if(stream.match(/<-|:=|<=|>=|<>|[+*/^%=<>-]/))return 'operator';
 stream.next();return null;
}});
