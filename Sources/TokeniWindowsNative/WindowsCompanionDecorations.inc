// Windows adaptations of the shared cosmetic slots. IDs match CompanionCosmeticID.allCases.
static unsigned int tokeni_cosmetics;
static void tokeni_cosmetics_ui(void *context)
{
    tokeni_cosmetics=*(unsigned int *)context;
    if(tokeni_overlay_window)InvalidateRect(tokeni_overlay_window,NULL,FALSE);
}
void tokeni_windows_overlay_set_cosmetics(unsigned int mask) { tokeni_windows_ui_invoke(tokeni_cosmetics_ui,&mask); }
static void tokeni_overlay_decorations(HDC dc,const RECT *r,int foreground)
{
    int w=r->right,h=r->bottom;
    HGDIOBJ oldbrush=SelectObject(dc,GetStockObject(NULL_BRUSH));
    for(int i=0;i<22;i++) {
        if(!(tokeni_cosmetics&(1U<<i)))continue;
        int front=i<5||i>=14;
        if(front!=foreground)continue;
        COLORREF color=RGB(90+(i*29)%150,100+(i*43)%140,110+(i*17)%130);
        HPEN pen=CreatePen(PS_SOLID,max(1,w/100),color);HGDIOBJ oldpen=SelectObject(dc,pen);
        if(i<5) {
            if(i==1||i==4)Ellipse(dc,w/8,h/8,w*7/8,h*7/8);
            else for(int p=0;p<6;p++) { int x=w*(p%3*3+1)/9,y=h*(p/3*7+1)/9; MoveToEx(dc,x-3,y,NULL);LineTo(dc,x+4,y);MoveToEx(dc,x,y-3,NULL);LineTo(dc,x,y+4); }
        } else if(i<9) {
            HBRUSH b=CreateSolidBrush(RGB(20+(i*7)%40,30+(i*11)%40,45+(i*13)%50));HGDIOBJ prev=SelectObject(dc,b);
            RoundRect(dc,4,4,w-4,h-4,w/5,h/5);SelectObject(dc,prev);DeleteObject(b);
            for(int x=10;x<w;x+=max(12,w/8)) { MoveToEx(dc,x,h/2,NULL);LineTo(dc,x,h-10); }
        } else if(i<11) { Rectangle(dc,w/10,h/10,w*9/10,h*9/10); }
        else if(i<14) { Ellipse(dc,w/5,h*4/5,w*4/5,h*9/10); }
        else if(i<16) { RoundRect(dc,3,3,w-3,h-3,i==14?4:w/4,i==14?4:h/4); }
        else if(i<19) { for(int p=0;p<7;p++) { int x=(p*37+11)%max(w,1),y=(p*53+17)%max(h,1); if(i==17) {MoveToEx(dc,2,y,NULL);LineTo(dc,w-2,y);} else Ellipse(dc,x,y,x+8,y+4); } }
        else { Ellipse(dc,w*4/5,h*3/5,w*19/20,h*3/4);MoveToEx(dc,w*4/5,h*5/8,NULL);LineTo(dc,w*19/20,h*5/8); }
        SelectObject(dc,oldpen);DeleteObject(pen);
    }
    SelectObject(dc,oldbrush);
}
