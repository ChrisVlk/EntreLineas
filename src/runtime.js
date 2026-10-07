import {convert} from './multilang.js';

// Interpret only the validated AST. Never eval student code or expose browser APIs.
export function* execute(source,language='pseint',limits={}) {
 const program=convert(source,language,'pseint');
 if(program.errors.length)throw Error(`Línea ${program.errors[0].line}: ${program.errors[0].message}`);
 if(program.empty)throw Error('Escribe un programa antes de ejecutarlo.');
 const values=new Map(),types=new Map();let steps=0,output=0,line=1;
 const fail=message=>{throw Error(`Línea ${program.sourceMap?.[line-1]||line}: ${message}`)};
 const tick=()=>{if(++steps>(limits.steps??100000))fail('Se alcanzó el límite de pasos. Revisa si hay un bucle infinito.');};
 function expression(a){tick();if(a.kind==='literal')return a.type==='int'||a.type==='real'?Number(a.v):a.v;
  if(a.kind==='variable')return values.get(a.v);
  if(a.kind==='unary'){const v=expression(a.a);return a.op==='no'?!v:a.op==='-'?-v:+v;}
  const x=expression(a.a);if(a.op==='y')return x&&expression(a.b);if(a.op==='o')return x||expression(a.b);
  const y=expression(a.b);let result;
  switch(a.op){case '+':result=x+y;break;case '-':result=x-y;break;case '*':result=x*y;break;case '/':case 'mod':case '%':if(y===0)fail('No se puede dividir entre cero.');result=a.op==='/'?x/y:x%y;break;case '^':result=x**y;break;case '=':case '==':return x===y;case '<>':case '!=':return x!==y;case '<':return x<y;case '>':return x>y;case '<=':return x<=y;case '>=':return x>=y;default:fail('Operador no compatible.');}
  if(!Number.isFinite(result))fail('El resultado numérico está fuera de rango.');
  if(a.type==='int'&&!Number.isSafeInteger(result))fail('El entero excede el rango seguro de esta consola.');return result;
 }
 function* block(nodes){for(const n of nodes){line=n.line;tick();switch(n.kind){
  case 'declare':for(const v of n.names){types.set(v,n.type);values.set(v,n.type==='str'?'':n.type==='bool'?false:0);}break;
  case 'assign':values.set(n.v,expression(n.value));break;
  case 'write':{const text=n.values.map(a=>{const v=expression(a);return typeof v==='boolean'?(v?'Verdadero':'Falso'):String(v)}).join('')+'\n';output+=text.length;if(output>(limits.output??100000))fail('Se alcanzó el límite de salida de la consola.');yield {type:'output',text};break;}
  case 'read':for(const name of n.names){let accepted=false;while(!accepted){const input=yield {type:'input',name,valueType:types.get(name)};const raw=String(input),trimmed=raw.trim(),type=types.get(name);let value=raw;
   if(type==='int'||type==='real'){value=Number(trimmed);accepted=Boolean(trimmed)&&Number.isFinite(value)&&(type!=='int'||Number.isSafeInteger(value));}
   else if(type==='bool'){accepted=/^(verdadero|falso|true|false|1|0)$/i.test(trimmed);value=/^(verdadero|true|1)$/i.test(trimmed);}
   else accepted=raw.length<=4096;
   if(accepted)values.set(name,value);else yield {type:'output',text:`Entrada inválida para ${name}. Se espera ${type==='int'?'un entero':type==='real'?'un número':type==='bool'?'Verdadero o Falso':'texto de hasta 4096 caracteres'}.\n`};
  }}break;
  case 'if':yield* block(expression(n.test)?n.body:n.other);break;
  case 'while':while((line=n.line,tick(),expression(n.test)))yield* block(n.body);break;
  case 'repeat':do{line=n.line;tick();yield* block(n.body);line=n.line;}while(!expression(n.test));break;
  case 'for':values.set(n.v,expression(n.start));while(true){line=n.line;tick();const end=expression(n.end),v=values.get(n.v);if(n.step>0?v>end:v<end)break;yield* block(n.body);const next=values.get(n.v)+n.step;if(!Number.isSafeInteger(next))fail('El contador excede el rango seguro.');values.set(n.v,next);}break;
  default:fail('Instrucción no compatible.');
 }}}
 yield* block(program.ast);
 return {steps};
}
