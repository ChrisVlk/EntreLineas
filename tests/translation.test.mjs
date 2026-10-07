import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {convert} from '../src/multilang.js';
const samples={
 pseint:'Algoritmo Prueba\nDefinir i, total Como Entero\ntotal <- 0\nPara i <- 1 Hasta 3 Hacer\ntotal <- total + i\nFinPara\nSi total = 6 Entonces\nEscribir "Total: ", total\nSiNo\nEscribir "error"\nFinSi\nFinAlgoritmo',
 python:'total = 0\nfor i in range(1, 4):\n    total += i\nif total == 6:\n    print("Total:", total)\nelse:\n    print("error")',
 javascript:'let total = 0;\nfor (let i = 1; i <= 3; i++) { total += i; }\nif (total === 6) { console.log("Total:", total); } else { console.log("error"); }',
 c:'#include <stdio.h>\nint main(void) { int total = 0; for (int i = 1; i <= 3; i++) { total += i; } if (total == 6) { printf("Total: %d\\n", total); } else { puts("error"); } return 0; }'
};
for(const from of Object.keys(samples))for(const to of Object.keys(samples))test(`${from} → ${to}: sum, loop, decision and output`,()=>{const r=convert(samples[from],from,to);assert.deepEqual(r.errors,[]);assert.ok(r.code);if(to==='javascript'){const output=[];vm.runInNewContext(r.code,{console:{log:(s)=>output.push(String(s))}},{timeout:1000});assert.equal(output.join('\n'),'Total: 6')}});
test('string contents are never rewritten as operators or comments',()=>{const r=convert('console.log("if === true // % Python");','javascript','pseint');assert.deepEqual(r.errors,[]);assert.match(r.code,/"if === true \/\/ % Python"/)});
test('unsupported syntax produces no misleading output',()=>{for(const [source,lang] of [['items = [1, 2, 3]','python'],['def suma(a):\n    return a + 1','python'],['fetch("/api");','javascript'],['int main(){ int x=5/2; printf("%d\\n",x); }','c'],['x = 1\n  print(x)','python']]){const r=convert(source,lang,'pseint');assert.equal(r.code,'');assert.ok(r.errors.length)}});
test('Python print separators and descending ranges',()=>{let r=convert('for i in range(3, 0, -1):\n    print("n=", i, sep="")','python','javascript');assert.deepEqual(r.errors,[]);let out=[];vm.runInNewContext(r.code,{console:{log:s=>out.push(s)}});assert.deepEqual(out,['n=3','n=2','n=1'])});
test('line diagnostics refer to input, not generated pseudocode',()=>{const r=convert('let a = 1;\nconsole.log(missing);','javascript','python');assert.equal(r.errors[0].line,2)});

test('Python range snapshots its limit and keeps the final loop variable semantics',()=>{const r=convert('limite = 4\nfor i in range(1, limite):\n    limite = 1\n    i = 50\nprint(i)','python','javascript');assert.deepEqual(r.errors,[]);let out=[];vm.runInNewContext(r.code,{console:{log:s=>out.push(s)}},{timeout:1000});assert.deepEqual(out,['50'])});
test('C integer subexpression is not silently converted into real division',()=>{assert.ok(convert('int main(){double a=1.5; int b=5; double c=a+b/2; printf("%g\\n",c);}','c','python').errors.length)});
