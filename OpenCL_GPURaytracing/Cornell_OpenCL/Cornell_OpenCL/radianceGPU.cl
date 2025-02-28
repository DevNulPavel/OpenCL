
typedef struct Ray_ {
    float3 o;
    float3 d;
    float3 inv_d;
    int3 sign;
}Ray;

typedef struct Sphere_{
    float rad;       // radius
    float3 p, e, c;      // position, emission, color
    unsigned int refl;      // reflection type (DIFFuse, SPECular, REFRactive)
}Sphere;
/* ------------------------------------------------------------------------------------------- */

typedef struct Triangle_ {
    float3 Vertex[3], Normal, Color, e;
    unsigned int  refl;
}Triangle;
 
/* ------------------------------------------------------------------------------------------- */

// returns distance, 0 if nohit
// Возвращает дистацию, либо 0 если нет пересечения
 float RaySphereIntersect(Ray r, Sphere sph){
     float3 op = sph.p-r.o; // Solve t^2*d.d + 2*t*(o-p).d + (o-p).(o-p)-R^2 = 0
     float t, eps=1e-4, b=dot(op,r.d), det=b*b-dot(op,op)+sph.rad*sph.rad;
     if (det<0.0) {
         return 0.0;
     }else{
         det=sqrt(det);
     }
     return (t=b-det)>eps ? t : ((t=b+det)>eps ? t : 0.0);
 }
/* ------------------------------------------------------------------------------------------- */

 
 float RayTriangleIntersect(Ray r, Triangle tri)
 {
 float det, inv_det, u,v;
 float3 edge1, edge2, tvec, pvec, qvec;
 
 edge1 = tri.Vertex[1] - tri.Vertex[0];
 edge2 = tri.Vertex[2] - tri.Vertex[0];
 
 pvec = cross(r.d,edge2);
 det  = dot(edge1, pvec);
 
 
 if ( det > 1e-5 && det < 1e-5)
 return 0;
 inv_det = 1.0 /det;
 
 
 /* calculate distance from vert0 to ray origin */
 tvec = r.o - tri.Vertex[0];

/* calculate U parameter and test bounds */

 u = dot(tvec,pvec) * inv_det;
 if ( u < 0.0 || u>1.0)
 return 0;
 
 /* prepare to test V parameter */
 qvec = cross(tvec, edge1);

/* calculate V parameter and test bounds */
 v = dot(r.d,qvec) * inv_det;
 if (v <0.0 || u + v > 1.0)
 return 0;
 /* calculate t, ray intersects triangle */
return dot(edge2, qvec) * inv_det;
 
 
 }

/* ------------------------------------------------------------------------------------------- */
                            /*  Random function */
/* ------------------------------------------------------------------------------------------- */
 float GetRandom(unsigned int *seed0, unsigned int *seed1) {
     *seed0 = 36969 * ((*seed0) & 65535) + ((*seed0) >> 16);
     *seed1 = 18000 * ((*seed1) & 65535) + ((*seed1) >> 16);
     
     unsigned int ires = ((*seed0) << 16) + (*seed1);
     
     union {
        float f;
        unsigned int ui;
     } res;
     res.ui = (ires & 0x007fffff) | 0x40000000;
     
     return (res.f - 2.0) / 2.0;
 }
 

/* ------------------------------------------------------------------------------------------- */
                        /* Main Radiance function */
/* ------------------------------------------------------------------------------------------- */
float3 radiance(Ray inputRay,
                __constant Sphere *spheres,
                __constant Triangle *triag,
                const int spheresCount,
                const int trianglesCount,
                unsigned int* seed0,
                unsigned int* seed1){
    
    Ray r = inputRay;
    unsigned int depth = 0;
    float3 color = {0.0, 0.0, 0.0}; // Базовый цвет
    float3 currentColor = {1.0, 1.0, 1.0};

    /* For recursion */
    while(1){
        /* Check ray-primitive intersection */
        float intersectDist = 1e20;
        const float inf = 1e20;                                // distance to intersection
        int id = 0;                               // id of intersected object
        int intersectionType = 0;
        float distanceToSphere = 0;
        float dispanceToTriangle = 0;

        int idSphere = 0;
        int idTriangle = 0;
        float lastDistToTriangle = inf;
        float lastDistToSphere = inf;

        for(int i = spheresCount; i--;){
            distanceToSphere = RaySphereIntersect(r, spheres[i]);
            if(distanceToSphere && (distanceToSphere < lastDistToSphere)){
                lastDistToSphere = distanceToSphere;
                idSphere = i;
            }
        }
        for(int i = trianglesCount; i--;) {
            dispanceToTriangle = RayTriangleIntersect(r, triag[i]);
            if(dispanceToTriangle && (dispanceToTriangle < lastDistToTriangle)){
                lastDistToTriangle = dispanceToTriangle;
                idTriangle = i;
            }
        }
        if(lastDistToSphere < intersectDist && lastDistToSphere < lastDistToTriangle){
            id = idSphere;
            intersectDist = lastDistToSphere;
            intersectionType = 1;
        }
        if( lastDistToTriangle < intersectDist && lastDistToTriangle < lastDistToSphere) {
            id = idTriangle;
            intersectDist = lastDistToTriangle;
            intersectionType = 2;
        }
        
        // Если нет пересечения - возвращаем черный цвет
        if(intersectDist >= inf){
            return color; // if miss, return black
        }
    
        /* -------------* Intersection happened *------------------*/
      
        if (intersectionType == 1) {
            // Столкновение со сферой
            const Sphere obj = spheres[id];        // the hit object
            
            // TODO: Test code
            //return obj.c;
            
            float3 rdir;
            rdir.x = r.d.x * intersectDist;
            rdir.y = r.d.y * intersectDist;
            rdir.z = r.d.z * intersectDist;

            float3 x = r.o + rdir;
            float3 n = (x - obj.p);
            n = normalize(n);
            float3 nl = dot(r.d,n);
            if (nl.x>=0 && nl.y>=0 && nl.z>0){
                n=-n;
            }
            float3 f=obj.c;
            
            float p = f.x>f.y && f.x>f.z ? f.x : f.y>f.z ? f.y : f.z; // max refl
            color = color + currentColor * obj.e;
            
            if (++depth > 5){
                if (GetRandom(seed0,seed1)<p) {
                    f=f*(1/p);
                }else {
                    // TODO: Test code
                    return float3(1.0, 0.0, 0.0); // if miss, return black
                    return color;
                }
            }
            currentColor = currentColor*f;
           
            if(obj.refl == 0) {
                 float r1 = 2.0f * 3.14159265358979323846f * GetRandom(seed0, seed1);
                 float r2 = GetRandom(seed0, seed1);
                 float r2s = sqrt(r2);
                
                 float3 w; {(w).x = (nl).x; (w).y = (nl).y; (w).z = (nl).z; };
                
                 float3 u, a;
                 if (fabs(w.x) > 0.1f) {
                     { (a).x = 0.0f; (a).y = 1.0f; (a).z = 0.0f; };
                     u=a;
                 } else {
                     { (a).x = 1.0f; (a).y = 0.0f; (a).z = 0.0f; };
                     a = cross(a,w);
                     u=a;
                 }
                 u=normalize(u);
                 float3 v;
                 v= cross(w,u);
                
                 float3 d;
                 float temp1 = cos(r1)*r2s;
                 float temp2 = sin(r1)*r2s;
                 float temp3 = sqrt(1-r2);
                
                 d.x = u.x * temp1 + v.x * temp2 + w.x * temp3;
                 d.y = u.y * temp1 + v.y * temp2 + w.y * temp3;
                 d.z = u.z * temp1 + v.z * temp2 + w.z * temp3;
                
                 d=normalize(d);
                
                 r.o = x;
                 r.d = d;
                
                
                 continue;
             }
             else if(obj.refl == 1)
             {
                 r.o = x;
                 float3 d;
                 d= r.d;
                 float ref=2.0 * dot(r.d,n);
                 float3 tempV;
                 tempV.x = n.x * ref;
                 tempV.y = n.y * ref;
                 tempV.z = n.z * ref;
                 d = r.d - tempV;
                 r.d = d;
                 
                 continue;
             }
             
             // Ideal dielectric REFRACTION
             Ray reflRay;
             reflRay.o = x;
             float3 d = r.d;
             float ref=2.0 * dot(r.d,n);
             float3 tempV;
             tempV.x = n.x * ref;
             tempV.y = n.y * ref;
             tempV.z = n.z * ref;
             d = r.d - tempV;
             reflRay.d = d;
             // Ray from outside going in?
             bool into = dot(n,nl) > 0;
             float nc=1.0, nt = 1.5, nnt=into?nc/nt:nt/nc, ddn =dot(r.d,nl), cos2t;
             // Total internal reflection
             if ((cos2t=1.0-nnt*nnt*(1.0-ddn*ddn))<0)
             {    // Total internal reflection
                 //return obj.e + f.mult(radiance(reflRay,depth,Xi));
                 r=reflRay;
                 continue;
             }
         
             float3  tdir;
             tdir.x = r.d.x * nnt - n.x* ((into?1.0:-1.0)* ddn*nnt+sqrt(cos2t));
             tdir.y = r.d.y * nnt - n.y* ((into?1.0:-1.0)* ddn*nnt+sqrt(cos2t));
             tdir.z = r.d.z * nnt - n.z* ((into?1.0:-1.0)* ddn*nnt+sqrt(cos2t));
             tdir=normalize(tdir);
             float a=nt-nc, b=nt+nc, R0=a*a/(b*b), c = 1.0 - (into?-ddn: dot(n,tdir));
             float Re=R0+(1.0 - R0) * c * c * c * c *c, Tr=1-Re, P=0.25+0.5 *Re, RP=Re/P, TP=Tr/(1.0-P);
            
            
             if (GetRandom(seed0, seed1)<P)
             {
                 currentColor=currentColor*RP;
                 r = reflRay;
             }
             else
             {
                 
                 currentColor=currentColor*TP;
                 r.o = x;
                 r.d = tdir;
             }
             continue;
             
            // TODO: Test code
            //return float3(1.0, 0.0, 1.0);
        }
        else {
            // Столкновение с треугольником
            
            // TODO: Test code
            //return float3(1.0, 0.0, 1.0); // if miss, return black

            const Triangle obj = triag[id];
            
            // TODO: Test code
            //return obj.Color;

            float3 rayVector;
            rayVector.x = r.d.x * intersectDist;
            rayVector.y = r.d.y * intersectDist;
            rayVector.z = r.d.z * intersectDist;
            
            // Вычисляем нормаль
            float3 x = r.o + rayVector;
            float3 n = cross(triag[id].Vertex[1] - triag[id].Vertex[0], triag[id].Vertex[2]-triag[id].Vertex[0]);
            n = normalize(n);
            float3 nl = dot(r.d,n);
            if (nl.x >= 0 && nl.y >= 0 && nl.z > 0) {
                n =- n;
            }
            
            // TODO: Test code
            //return n;
            
            float3 triangleColor = obj.Color;
            
            // TODO: Test code
            //return obj.Color;
            
            float p = triangleColor.x > triangleColor.y && triangleColor.x>triangleColor.z ? triangleColor.x : triangleColor.y>triangleColor.z ? triangleColor.y : triangleColor.z; // max refl
            color = color + currentColor*obj.e;
            
            if (++depth > 3){
                if (GetRandom(seed0, seed1) < p) {
                    triangleColor = triangleColor*(1/p);
                }else{
                    return color;
                }
                
                // TODO: Test code
                //return color;
            }
            currentColor = currentColor * triangleColor;
            
            // TODO: Test code
            //return currentColor;
            //return triangleColor;
         
            if(obj.refl == 0) {
                float r1 = 2.0f * 3.14159265358979323846f * GetRandom(seed0, seed1);
                float r2 = GetRandom(seed0, seed1);
                float r2s = sqrt(r2);

                float3 w; {(w).x = (nl).x; (w).y = (nl).y; (w).z = (nl).z; };

                float3 u, a;
                if (fabs(w.x) > 0.1f) {
                    { (a).x = 0.0f; (a).y = 1.0f; (a).z = 0.0f; };
                    u=a;
                } else {
                    { (a).x = 1.0f; (a).y = 0.0f; (a).z = 0.0f; };
                    a = cross(a,w);
                    u=a;
                }
                u = normalize(u);
                float3 v;
                v = cross(w,u);

                float3 d;
                float temp1 = cos(r1)*r2s;
                float temp2 = sin(r1)*r2s;
                float temp3 = sqrt(1-r2);

                d.x = u.x * temp1 + v.x * temp2 + w.x * temp3;
                d.y = u.y * temp1 + v.y * temp2 + w.y * temp3;
                d.z = u.z * temp1 + v.z * temp2 + w.z * temp3;

                d=normalize(d);

                r.o = x;
                r.d = d;

                continue;
             }else if(obj.refl == 1) {
                 r.o = x;
                 float3 d;
                 d= r.d;
                 float ref=2.0 * dot(r.d,n);
                 float3 tempV;
                 tempV.x = n.x * ref;
                 tempV.y = n.y * ref;
                 tempV.z = n.z * ref;
                 d = r.d - tempV;
                 r.d = d;

                 continue;
             }else if(obj.refl == 2){
                 // Ideal dielectric REFRACTION
                 Ray reflRay;
                 reflRay.o = x;
                 float3 d = r.d;
                 float ref=2.0 * dot(r.d,n);
                 float3 tempV;
                 tempV.x = n.x * ref;
                 tempV.y = n.y * ref;
                 tempV.z = n.z * ref;
                 d = r.d - tempV;
                 reflRay.d = d;
                 // Ray from outside going in?
                 bool into = dot(n,nl) > 0;
                 float nc=1.0, nt = 1.5, nnt=into?nc/nt:nt/nc, ddn =dot(r.d,nl), cos2t;
                 // Total internal reflection
                 if ((cos2t=1.0-nnt*nnt*(1.0-ddn*ddn))<0) {
                     // Total internal reflection
                     // TODO: For test
                     //return obj.e + f.mult(radiance(reflRay,depth,Xi));
                     
                     r=reflRay;
                     continue;
                 }
                  
                  float3  tdir;
                  tdir.x = r.d.x * nnt - n.x* ((into?1.0:-1.0)* ddn*nnt+sqrt(cos2t));
                  tdir.y = r.d.y * nnt - n.y* ((into?1.0:-1.0)* ddn*nnt+sqrt(cos2t));
                  tdir.z = r.d.z * nnt - n.z* ((into?1.0:-1.0)* ddn*nnt+sqrt(cos2t));
                  tdir = normalize(tdir);
                  float a = nt-nc, b=nt+nc, R0=a*a/(b*b), c = 1.0 - (into?-ddn: dot(n,tdir));
                  float Re = R0+(1.0 - R0) * c * c * c * c *c, Tr=1-Re, P=0.25+0.5 *Re, RP=Re/P, TP=Tr/(1.0-P);
                  
                  if (GetRandom(seed0, seed1)<P){
                      currentColor=currentColor*RP;
                      r = reflRay;
                  } else {
                      currentColor=currentColor*TP;
                      r.o = x;
                      r.d = tdir;
                  }
             }

            continue;
        }
    }
}

/* ------------------------------------------------------------------------------------------- */
                                // Generate the Ray //
/* ------------------------------------------------------------------------------------------- */

Ray genRay(const int width,
           const int height,
           const int x,
           const int y,
           int sx,
           int sy,
           unsigned int* seed0,
           unsigned int* seed1) {
    
    Ray r;
    float r1 = 2.0 * GetRandom(seed0, seed1);
    float dx = (r1<1) ? sqrt(r1)-1 : 1-sqrt(2-r1);
    float r2 = 2.0 * GetRandom(seed0, seed1);
    float dy = (r2<1) ? sqrt(r2)-1 : 1-sqrt(2-r2);
    
    float3 camOrigin = {50, 52, 295.6};
    float3 camDir = {0, -0.042612, -1};
    camDir = normalize(camDir);
    float3 cx;
    cx.x = width*0.5135/height;
    cx.y = 0.0;
    cx.z = 0.0;

    float3 cy;
    cy = cross(cx,camDir);
    cy = normalize(cy);
    cy.x = cy.x *0.5135;
    cy.y = cy.y *0.5135;
    cy.z = cy.z *0.5135;

    float3 temp1;
    temp1.x = ((sx+0.5 + dx)/2.0 + x)/width - 0.5;
    temp1.y = ((sx+0.5 + dx)/2.0 + x)/width - 0.5;
    temp1.z = ((sx+0.5 + dx)/2.0 + x)/width - 0.5;

    float3 temp2;
    temp2.x = ( (sy+0.5 + dy)/2.0 + y)/height - 0.5;
    temp2.y = ( (sy+0.5 + dy)/2.0 + y)/height - 0.5;
    temp2.z = ( (sy+0.5 + dy)/2.0 + y)/height - 0.5;

    float3 d = cx*temp1 + cy*temp2 + camDir;

    d.x = d.x *140.0;
    d.y = d.y *140.0;
    d.z = d.z *140.0;

    r.o = camOrigin+d;
    r.d = normalize(d);
    return r;
}
 

__kernel void radianceGPU(__global float3* colors,
                          __constant Sphere* spheres,
                          __constant Triangle* triag,
                          __global unsigned int* randomInput,
                          const int width,
                          const int height,
                          const unsigned int sphereCount,
                          const unsigned int triangleCount,
                          const unsigned int samps){
    
    const int gid = get_global_id(0); // Текущая позиция в общей сетке
    const int gid2 = 2 * gid;
    const int x = gid % width;
    const int y = gid / width;
    
    if (y >= height){
        return;
    }
    
    unsigned int seed0 = randomInput[gid2];
    unsigned int seed1 = randomInput[gid2+1];
    unsigned int i = (height-y-1)*width+x;
    
    // Выходной цвет
    colors[i].x = 0.0;
    colors[i].y = 0.0;
    colors[i].z = 0.0;
    
    const float3 invSamps = {1.0/samps,1.0/samps,1.0/samps};
    float3 r = {0.0, 0.0, 0.0};
    for (unsigned int sy = 0; sy < 2; sy++){    // 2x2 subpixel rows
        for (unsigned int sx = 0; sx < 2; sx++){// 2x2 subpixel cols
            
            // Camera rays are pushed ^^^^^ forward to start in interior
            for (unsigned int s = 0; s < samps; s++){
                Ray ray = genRay(width, height, x, y, sx, sy, &seed0, &seed1);
                r = r + radiance(ray, spheres, triag, sphereCount, triangleCount, &seed0, &seed1) * invSamps;
            }
            
            colors[i].x = colors[i].x + clamp((float)r.x, (float)0.0, (float)1.0)*0.25;
            colors[i].y = colors[i].y + clamp((float)r.y, (float)0.0, (float)1.0)*0.25;
            colors[i].z = colors[i].z + clamp((float)r.z, (float)0.0, (float)1.0)*0.25;
        }
    }
    //randomInput[gid2] = seed0;
    //randomInput[gid2+1] = seed1;
}
